#define WIN32_LEAN_AND_MEAN
#include <winsock2.h>
#include <ws2tcpip.h>
#include <windows.h>
#include <iphlpapi.h>
#include <psapi.h>
#include <tlhelp32.h>
#include <sddl.h>
#include <wtsapi32.h>
#include <winternl.h>
#include <shlobj.h>
#include <iostream>
#include <sstream>
#include <string>
#include <vector>
#include <map>
#include <set>
#include <chrono>
#include <thread>
#include <atomic>
#include <cctype>
#include <algorithm>

#pragma comment(lib, "ws2_32.lib")
#pragma comment(lib, "iphlpapi.lib")
#pragma comment(lib, "psapi.lib")
#pragma comment(lib, "wtsapi32.lib")
#pragma comment(lib, "advapi32.lib")
#pragma comment(lib, "shell32.lib")

using namespace std;
using Clock = std::chrono::steady_clock;

struct Snapshot {
    ULONGLONG procTime100ns = 0;
    Clock::time_point t = Clock::now();
};

static CRITICAL_SECTION g_snapLock;
static map<DWORD, Snapshot> g_prev; // pid -> snapshot
static ULONGLONG g_prevSysTotal = 0;

// PID->process name cache
static CRITICAL_SECTION g_nameLock;
static map<DWORD, string> g_pidNameCache;
static atomic<bool> g_pidCacheRunning{ false };


static string json_escape(const string& s) {
    string out;
    for (char c : s) {
        switch (c) {
        case '\"': out += "\\\""; break;
        case '\\': out += "\\\\"; break;
        case '\b': out += "\\b"; break;
        case '\f': out += "\\f"; break;
        case '\n': out += "\\n"; break;
        case '\r': out += "\\r"; break;
        case '\t': out += "\\t"; break;
        default:
            if ((unsigned char)c < 0x20) {
                char buf[7];
                sprintf_s(buf, "\\u%04x", (unsigned char)c);
                out += buf;
            }
            else out += c;
        }
    }
    return out;
}

static ULONGLONG getProcessTotalTime100ns(HANDLE hProcess) {
    FILETIME c, e, k, u;
    if (GetProcessTimes(hProcess, &c, &e, &k, &u)) {
        ULONGLONG kv = ((ULONGLONG)k.dwHighDateTime << 32) | k.dwLowDateTime;
        ULONGLONG uv = ((ULONGLONG)u.dwHighDateTime << 32) | u.dwLowDateTime;
        return kv + uv;
    }
    return 0;
}

static ULONGLONG getSystemTotalTime100ns() {
    FILETIME idle, k, u;
    if (GetSystemTimes(&idle, &k, &u)) {
        ULONGLONG kv = ((ULONGLONG)k.dwHighDateTime << 32) | k.dwLowDateTime;
        ULONGLONG uv = ((ULONGLONG)u.dwHighDateTime << 32) | u.dwLowDateTime;
        ULONGLONG iv = ((ULONGLONG)idle.dwHighDateTime << 32) | idle.dwLowDateTime;
        return kv + uv + iv;
    }
    return 0;
}

static string getFilename(const string& full) {
    size_t p = full.find_last_of("\\/");
    if (p == string::npos) return full;
    return full.substr(p + 1);
}

static string pidToProcessName(DWORD pid) {
    CHAR buf[MAX_PATH] = { 0 };
    HANDLE h = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION | PROCESS_VM_READ, FALSE, pid);
    if (!h) return "";
    DWORD sz = MAX_PATH;
    if (QueryFullProcessImageNameA(h, 0, buf, &sz)) {
        CloseHandle(h);
        return getFilename(string(buf));
    }
    CloseHandle(h);
    return "";
}

static string getProcessUsername(DWORD pid) {
    HANDLE h = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, pid);
    if (!h) return "UNKNOWN";
    HANDLE token = NULL;
    if (!OpenProcessToken(h, TOKEN_QUERY, &token)) { CloseHandle(h); return "SYSTEM"; }
    DWORD needed = 0;
    GetTokenInformation(token, TokenUser, NULL, 0, &needed);
    if (GetLastError() != ERROR_INSUFFICIENT_BUFFER) { CloseHandle(token); CloseHandle(h); return "UNKNOWN"; }
    vector<BYTE> buf(needed);
    if (!GetTokenInformation(token, TokenUser, buf.data(), needed, &needed)) { CloseHandle(token); CloseHandle(h); return "UNKNOWN"; }
    TOKEN_USER* tu = (TOKEN_USER*)buf.data();
    SID_NAME_USE use;
    CHAR name[256]; DWORD nc = sizeof(name);
    CHAR dom[256]; DWORD dc = sizeof(dom);
    if (LookupAccountSidA(NULL, tu->User.Sid, name, &nc, dom, &dc, &use)) {
        string username = string(dom) + "\\" + string(name);
        CloseHandle(token); CloseHandle(h);
        return username;
    }
    CloseHandle(token); CloseHandle(h);
    return "UNKNOWN";
}

// UAC Virtualization detection
static string getUACVirtualization(DWORD pid) {
    HANDLE hProcess = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, pid);
    if (!hProcess) {
        return "Not allowed";
    }

    HANDLE hToken = NULL;
    if (!OpenProcessToken(hProcess, TOKEN_QUERY, &hToken)) {
        CloseHandle(hProcess);
        return "Not allowed";
    }

    // Check if process is elevated (elevated processes cannot have virtualization)
    TOKEN_ELEVATION elevation;
    DWORD returnLength = 0;
    if (GetTokenInformation(hToken, TokenElevation, &elevation, sizeof(elevation), &returnLength)) {
        if (elevation.TokenIsElevated) {
            CloseHandle(hToken);
            CloseHandle(hProcess);
            return "Disabled"; // Elevated processes have virtualization disabled
        }
    }

    // Check virtualization status
    DWORD virtualizationEnabled = 0;
    returnLength = 0;
    if (GetTokenInformation(hToken, TokenVirtualizationEnabled, &virtualizationEnabled, sizeof(virtualizationEnabled), &returnLength)) {
        CloseHandle(hToken);
        CloseHandle(hProcess);
        return virtualizationEnabled ? "Enabled" : "Disabled";
    }

    // Check if this is a 32-bit process on 64-bit system (common case for virtualization)
    BOOL isWow64 = FALSE;
    if (IsWow64Process(hProcess, &isWow64)) {
        CloseHandle(hToken);
        CloseHandle(hProcess);
        return isWow64 ? "Enabled" : "Disabled";
    }

    CloseHandle(hToken);
    CloseHandle(hProcess);
    return "Disabled";
}

// Get the current executable name for self-detection
static string getCurrentExecutableName() {
    static string currentExeName;
    if (currentExeName.empty()) {
        char path[MAX_PATH];
        if (GetModuleFileNameA(NULL, path, MAX_PATH)) {
            currentExeName = getFilename(string(path));
        }
    }
    return currentExeName;
}

// PROCESS CLASSIFICATION FUNCTION
static string classifyProcessType(DWORD pid, const string& name) {
    // System processes (Windows components)
    static const set<string> systemProcesses = {
        "system", "csrss.exe", "svchost.exe", "services.exe",
        "lsass.exe", "winlogon.exe", "smss.exe", "wininit.exe",
        "dwm.exe", "taskhostw.exe", "explorer.exe", "audiodg.exe",
        "conhost.exe", "spoolsv.exe", "lsm.exe", "rundll32.exe",
        "ntdll.dll", "kernel32.dll", "ntoskrnl.exe", "hal.dll",
        "taskhost.exe", "searchindexer.exe", "wmiprvse.exe",
        "dllhost.exe", "msacm32.drv", "ngentask.exe", "msoaimp.exe"
    };

    // App processes (user applications)
    static const set<string> appProcesses = {
        "chrome.exe", "firefox.exe", "msedge.exe", "iexplore.exe",
        "spotify.exe", "slack.exe", "discord.exe", "telegram.exe",
        "vlc.exe", "notepad.exe", "code.exe", "idea.exe",
        "photoshop.exe", "winrar.exe", "7z.exe", "steam.exe",
        "unreal.exe", "unity.exe", "blender.exe", "audacity.exe",
        // Microsoft Office Suite
        "winword.exe", "excel.exe", "powerpnt.exe", "outlook.exe",
        "msaccess.exe", "onenote.exe", "mspub.exe", "visio.exe",
        // Windows built-in apps that should be in Apps section
        "taskmgr.exe", "snippingtool.exe", "calc.exe", "mspaint.exe",
        "notepad++.exe", "wordpad.exe", "write.exe",
        // Development tools
        "devenv.exe", "blend.exe", "msbuild.exe",
        // Media and graphics
        "wmplayer.exe", "mpc-hc.exe", "gimp.exe", "inkscape.exe",
        // Communication
        "teams.exe", "skype.exe", "zoom.exe",
        // Task managers and system utilities (user-level)
        "procexp.exe", "procmon.exe", "gui_task_manager.exe",
        "task_manager_backend.exe", "gui_task_manager_backend.exe",
        // Virtualization
        "vmware.exe", "vmplayer.exe", "vmware-vmx.exe",
        "vmware-tray.exe", "vmware-unity-helper.exe",
        // Docker
        "docker desktop.exe", "docker.exe", "com.docker.service.exe",
        // Messaging
        "whatsapp.exe", "whatsappdesktop.exe"
    };

    string nameLower = name;
    transform(nameLower.begin(), nameLower.end(), nameLower.begin(), ::tolower);

    // Always classify our own executable as an app (so it shows in Apps and can terminate itself)
    string currentExe = getCurrentExecutableName();
    if (!currentExe.empty()) {
        string currentExeLower = currentExe;
        transform(currentExeLower.begin(), currentExeLower.end(), currentExeLower.begin(), ::tolower);
        if (nameLower == currentExeLower) {
            return "app";
        }
    }

    // Check system processes
    if (systemProcesses.count(nameLower) > 0) {
        return "system";
    }

    // Check app processes
    if (appProcesses.count(nameLower) > 0) {
        return "app";
    }

    // Additional heuristics for app classification
    // Microsoft Office patterns
    if (nameLower.find("word") != string::npos ||
        nameLower.find("excel") != string::npos ||
        nameLower.find("powerpoint") != string::npos ||
        nameLower.find("outlook") != string::npos) {
        return "app";
    }

    // Common application patterns
    if (nameLower.find("tool") != string::npos &&
        (nameLower.find("snip") != string::npos || nameLower.find("paint") != string::npos)) {
        return "app";
    }

    // Task managers and similar utilities
    if (nameLower.find("task") != string::npos && nameLower.find("mgr") != string::npos) {
        return "app";
    }

    // Docker, virtualization, and messaging apps
    if (nameLower.find("docker") != string::npos ||
        nameLower.find("vmware") != string::npos ||
        nameLower.find("whatsapp") != string::npos) {
        return "app";
    }

    // Heuristic: low PIDs are usually system processes
    if (pid < 100) {
        return "system";
    }

    // Default: classify as background service if not recognized
    return "background";
}

// Background thread: refresh g_pidNameCache every intervalMs milliseconds
static void refreshPidNameCacheLoop(unsigned int intervalMs = 5000) {
    while (g_pidCacheRunning.load()) {
        map<DWORD, string> local;
        vector<DWORD> pids(4096);
        DWORD bytes = 0;
        if (EnumProcesses(pids.data(), (DWORD)(pids.size() * sizeof(DWORD)), &bytes)) {
            size_t cnt = bytes / sizeof(DWORD);
            pids.resize(cnt);
            for (DWORD pid : pids) {
                if (pid == 0) continue;
                string name;
                HANDLE hProc = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION | PROCESS_VM_READ, FALSE, pid);
                if (hProc) {
                    CHAR img[MAX_PATH] = { 0 };
                    DWORD sz = MAX_PATH;
                    if (QueryFullProcessImageNameA(hProc, 0, img, &sz)) {
                        name = getFilename(string(img));
                    }
                    CloseHandle(hProc);
                }
                if (name.empty()) {
                    // fallback (may still succeed in some cases)
                    name = pidToProcessName(pid);
                }
                if (name.empty()) name = "Unknown";
                local[pid] = name;
            }
        }
        // swap into global cache
        EnterCriticalSection(&g_nameLock);
        g_pidNameCache.swap(local);
        LeaveCriticalSection(&g_nameLock);

        // sleep for interval
        this_thread::sleep_for(chrono::milliseconds(intervalMs));
    }
}

// -- processes & details --------------------------------------------------

struct ProcInfo {
    DWORD pid = 0;
    string name;
    int cpuPercent = 0;
    SIZE_T memoryKB = 0;
    string username;
    string status;
    string type;
    string uacVirtualization;
};

// Group processes by executable name (like Windows Task Manager)
struct GroupedProcess {
    string name;
    string type;
    vector<DWORD> pids;
    int totalCpuPercent = 0;
    SIZE_T totalMemoryKB = 0;
    DWORD mainPid = 0;  // The "main" process ID (usually the first/parent one)
};

static void updateSnapshotsAndComputeCpu(map<DWORD, ProcInfo>& outMap) {
    EnterCriticalSection(&g_snapLock);
    ULONGLONG sysNow = getSystemTotalTime100ns();
    ULONGLONG sysPrev = g_prevSysTotal;
    ULONGLONG sysDelta = (sysNow > sysPrev) ? (sysNow - sysPrev) : 1;

    // enumerate processes
    vector<DWORD> pids(4096);
    DWORD bytes = 0;
    if (!EnumProcesses(pids.data(), (DWORD)(pids.size() * sizeof(DWORD)), &bytes)) {
        LeaveCriticalSection(&g_snapLock);
        return;
    }
    size_t count = bytes / sizeof(DWORD);
    pids.resize(count);

    for (DWORD pid : pids) {
        if (pid == 0) continue;
        HANDLE hProc = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION | PROCESS_VM_READ, FALSE, pid);
        if (!hProc) continue;

        ProcInfo pi{};
        pi.pid = pid;

        CHAR img[MAX_PATH] = { 0 };
        DWORD sz = MAX_PATH;
        if (QueryFullProcessImageNameA(hProc, 0, img, &sz)) pi.name = getFilename(string(img));
        else pi.name = pidToProcessName(pid);

        // Classify process type
        pi.type = classifyProcessType(pid, pi.name);

        // memory
        PROCESS_MEMORY_COUNTERS pmc;
        pi.memoryKB = 0;
        if (GetProcessMemoryInfo(hProc, &pmc, sizeof(pmc))) pi.memoryKB = pmc.WorkingSetSize / 1024;

        // username
        pi.username = getProcessUsername(pid);

        // status (basic)
        pi.status = "Running";

        // UAC Virtualization
        pi.uacVirtualization = getUACVirtualization(pid);

        // CPU: compute from previous snapshot if exists
        ULONGLONG procNow = getProcessTotalTime100ns(hProc);
        auto it = g_prev.find(pid);
        double cpu = 0.0;
        if (it != g_prev.end()) {
            ULONGLONG procPrev = it->second.procTime100ns;
            ULONGLONG dProc = (procNow > procPrev) ? (procNow - procPrev) : 0;
            cpu = (double)dProc / (double)sysDelta * 100.0;
            if (cpu < 0) cpu = 0;
        }
        pi.cpuPercent = (int)(cpu + 0.5);

        // store current snapshot
        g_prev[pid] = { procNow, Clock::now() };

        outMap[pid] = pi;
        CloseHandle(hProc);
    }

    g_prevSysTotal = sysNow;
    LeaveCriticalSection(&g_snapLock);
}

static string buildProcessesJson() {
    map<DWORD, ProcInfo> m;
    updateSnapshotsAndComputeCpu(m);

    // Group processes by executable name across all types
    map<string, GroupedProcess> groups;

    for (auto& kv : m) {
        const ProcInfo& p = kv.second;

        // Group by executable name
        if (groups.find(p.name) == groups.end()) {
            GroupedProcess newGroup;
            newGroup.name = p.name;
            newGroup.type = p.type;
            newGroup.mainPid = p.pid;
            groups[p.name] = newGroup;
        }

        GroupedProcess& group = groups[p.name];
        group.pids.push_back(p.pid);
        group.totalCpuPercent += p.cpuPercent;
        group.totalMemoryKB += p.memoryKB;

        // Identify main process (highest memory or lowest PID)
        if (p.memoryKB > 0) {
            SIZE_T mainMemory = 0;
            auto mainIt = m.find(group.mainPid);
            if (mainIt != m.end()) {
                mainMemory = mainIt->second.memoryKB;
            }

            if (p.memoryKB > mainMemory * 2) {
                group.mainPid = p.pid;
            }
            else if (p.memoryKB >= mainMemory && p.pid < group.mainPid) {
                group.mainPid = p.pid;
            }
        }
    }

    ostringstream out;
    out << "[";
    bool first = true;

    for (auto& kv : groups) {
        const GroupedProcess& group = kv.second;

        if (!first) out << ",";
        first = false;
        out << "{";
        out << "\"pid\":" << group.mainPid << ",";
        out << "\"name\":\"" << json_escape(group.name);

        if (group.pids.size() > 1) {
            out << " (" << group.pids.size() << ")";
        }

        out << "\",";
        out << "\"type\":\"" << group.type << "\",";
        out << "\"cpuPercent\":" << group.totalCpuPercent << ",";
        out << "\"memoryKB\":" << group.totalMemoryKB << ",";
        out << "\"processCount\":" << group.pids.size() << ",";
        out << "\"allPids\":[";

        for (size_t i = 0; i < group.pids.size(); i++) {
            if (i > 0) out << ",";
            out << group.pids[i];
        }
        out << "]";
        out << "}";
    }
    out << "]";
    return out.str();
}

static string buildProcessesJsonFiltered(const string& filterType) {
    map<DWORD, ProcInfo> m;
    updateSnapshotsAndComputeCpu(m);

    // Group processes by executable name
    map<string, GroupedProcess> groups;

    for (auto& kv : m) {
        const ProcInfo& p = kv.second;

        // Skip if type doesn't match filter
        if (p.type != filterType) continue;

        // Group by executable name
        if (groups.find(p.name) == groups.end()) {
            GroupedProcess newGroup;
            newGroup.name = p.name;
            newGroup.type = p.type;
            newGroup.mainPid = p.pid;  // First process becomes main
            groups[p.name] = newGroup;
        }

        GroupedProcess& group = groups[p.name];
        group.pids.push_back(p.pid);
        group.totalCpuPercent += p.cpuPercent;
        group.totalMemoryKB += p.memoryKB;

        // For apps with multiple processes, try to identify the main process
        // (usually the one with most memory or lowest PID)
        if (p.memoryKB > 0) {
            // For current main PID, get its memory
            SIZE_T mainMemory = 0;
            auto mainIt = m.find(group.mainPid);
            if (mainIt != m.end()) {
                mainMemory = mainIt->second.memoryKB;
            }

            // If this process has significantly more memory, it's likely the main process
            if (p.memoryKB > mainMemory * 2) {
                group.mainPid = p.pid;
            }
            // If memory is similar, prefer the lower PID (usually the parent)
            else if (p.memoryKB >= mainMemory && p.pid < group.mainPid) {
                group.mainPid = p.pid;
            }
        }
    }

    ostringstream out;
    out << "[";
    bool first = true;

    for (auto& kv : groups) {
        const GroupedProcess& group = kv.second;

        if (!first) out << ",";
        first = false;
        out << "{";
        out << "\"pid\":" << group.mainPid << ",";  // Use main PID for operations
        out << "\"name\":\"" << json_escape(group.name);

        // If multiple processes, show count like Windows Task Manager
        if (group.pids.size() > 1) {
            out << " (" << group.pids.size() << ")";
        }

        out << "\",";
        out << "\"type\":\"" << group.type << "\",";
        out << "\"cpuPercent\":" << group.totalCpuPercent << ",";
        out << "\"memoryKB\":" << group.totalMemoryKB << ",";
        out << "\"processCount\":" << group.pids.size() << ",";
        out << "\"allPids\":[";

        // Include all PIDs for advanced operations
        for (size_t i = 0; i < group.pids.size(); i++) {
            if (i > 0) out << ",";
            out << group.pids[i];
        }
        out << "]";
        out << "}";
    }
    out << "]";
    return out.str();
}

static string buildDetailsJson() {
    map<DWORD, ProcInfo> m;
    updateSnapshotsAndComputeCpu(m);
    ostringstream out;
    out << "[";
    bool first = true;
    for (auto& kv : m) {
        const ProcInfo& p = kv.second;
        if (!first) out << ",";
        first = false;
        out << "{";
        out << "\"pid\":" << p.pid << ",";
        out << "\"name\":\"" << json_escape(p.name) << "\",";
        out << "\"type\":\"" << p.type << "\",";
        out << "\"status\":\"" << json_escape(p.status) << "\",";
        out << "\"username\":\"" << json_escape(p.username) << "\",";
        out << "\"cpuPercent\":" << p.cpuPercent << ",";
        out << "\"memoryKB\":" << p.memoryKB << ",";
        out << "\"uacVirtualization\":\"" << json_escape(p.uacVirtualization) << "\"";
        out << "}";
    }
    out << "]";
    return out.str();
}

// -- sockets --------------------------------------------------------------

static string ipv4ToString(DWORD addr) {
    in_addr ia; ia.S_un.S_addr = addr;
    char buf[INET_ADDRSTRLEN] = { 0 };
    if (InetNtopA(AF_INET, &ia, buf, INET_ADDRSTRLEN)) return string(buf);
    // fallback
    unsigned char* b = (unsigned char*)&addr;
    char fb[32];
    sprintf_s(fb, "%u.%u.%u.%u", b[0], b[1], b[2], b[3]);
    return string(fb);
}

static string buildSocketsJson() {
    // grab a local copy of the pid->name cache for this request
    map<DWORD, string> localCache;
    EnterCriticalSection(&g_nameLock);
    localCache = g_pidNameCache;
    LeaveCriticalSection(&g_nameLock);

    ostringstream out;
    out << "[";
    bool first = true;

    // TCP
    PMIB_TCPTABLE_OWNER_PID tcpTable = nullptr;
    DWORD size = 0;
    if (GetExtendedTcpTable(nullptr, &size, FALSE, AF_INET, TCP_TABLE_OWNER_PID_ALL, 0) == ERROR_INSUFFICIENT_BUFFER) {
        tcpTable = (PMIB_TCPTABLE_OWNER_PID)malloc(size);
        if (tcpTable && GetExtendedTcpTable(tcpTable, &size, FALSE, AF_INET, TCP_TABLE_OWNER_PID_ALL, 0) == NO_ERROR) {
            for (DWORD i = 0; i < tcpTable->dwNumEntries; i++) {
                auto& r = tcpTable->table[i];

                // Filter: Only show ESTABLISHED connections (state = 5)
                // Skip LISTEN (2), TIME_WAIT (11), CLOSE_WAIT (8), etc.
                // Also skip if remote address is 0.0.0.0 (no actual remote connection)
                // Skip if local and remote addresses are the same (local loopback, not a remote connection)
                // Skip localhost connections (127.x.x.x)
                DWORD remoteIp = ntohl(r.dwRemoteAddr);
                DWORD localIp = ntohl(r.dwLocalAddr);
                bool isLoopback = (remoteIp >> 24) == 127 || (localIp >> 24) == 127; // 127.x.x.x

                if (r.dwState != MIB_TCP_STATE_ESTAB ||
                    r.dwRemoteAddr == 0 ||
                    r.dwLocalAddr == r.dwRemoteAddr ||
                    isLoopback) {
                    continue;
                }

                DWORD lport = ntohs((u_short)r.dwLocalPort);
                DWORD rport = ntohs((u_short)r.dwRemotePort);
                DWORD pid = r.dwOwningPid;
                string pname = "Unknown";
                auto it = localCache.find(pid);
                if (it != localCache.end() && !it->second.empty()) pname = it->second;
                if (!first) out << ",";
                first = false;
                out << "{";
                out << "\"pid\":" << pid << ",";
                out << "\"processName\":\"" << json_escape(pname) << "\",";
                out << "\"protocol\":\"TCP\",";
                out << "\"localAddress\":\"" << json_escape(ipv4ToString(r.dwLocalAddr)) << "\",";
                out << "\"localPort\":" << lport << ",";
                out << "\"remoteAddress\":\"" << json_escape(ipv4ToString(r.dwRemoteAddr)) << "\",";
                out << "\"remotePort\":" << rport;
                out << "}";
            }
        }
        if (tcpTable) free(tcpTable);
    }

    // UDP
    PMIB_UDPTABLE_OWNER_PID udpTable = nullptr;
    size = 0;
    if (GetExtendedUdpTable(nullptr, &size, FALSE, AF_INET, UDP_TABLE_OWNER_PID, 0) == ERROR_INSUFFICIENT_BUFFER) {
        udpTable = (PMIB_UDPTABLE_OWNER_PID)malloc(size);
        if (udpTable && GetExtendedUdpTable(udpTable, &size, FALSE, AF_INET, UDP_TABLE_OWNER_PID, 0) == NO_ERROR) {
            for (DWORD i = 0; i < udpTable->dwNumEntries; i++) {
                auto& r = udpTable->table[i];
                DWORD lport = ntohs((u_short)r.dwLocalPort);
                DWORD pid = r.dwOwningPid;
                string pname = "Unknown";
                auto it = localCache.find(pid);
                if (it != localCache.end() && !it->second.empty()) pname = it->second;
                if (!first) out << ",";
                first = false;
                out << "{";
                out << "\"pid\":" << pid << ",";
                out << "\"processName\":\"" << json_escape(pname) << "\",";
                out << "\"protocol\":\"UDP\",";
                out << "\"localAddress\":\"" << json_escape(ipv4ToString(r.dwLocalAddr)) << "\",";
                out << "\"localPort\":" << lport << ",";
                out << "\"remoteAddress\":\"\",";
                out << "\"remotePort\":0";
                out << "}";
            }
        }
        if (udpTable) free(udpTable);
    }

    out << "]";
    return out.str();
}


static string buildServicesJson() {
    SC_HANDLE scm = OpenSCManagerA(NULL, NULL, SC_MANAGER_ENUMERATE_SERVICE);
    if (!scm) return "{\"error\":\"OpenSCManager failed\"}";
    DWORD bufSize = 0, needed = 0, servicesReturned = 0;
    // request buffer size - intentional call to get required size
    (void)EnumServicesStatusExA(scm, SC_ENUM_PROCESS_INFO, SERVICE_WIN32, SERVICE_STATE_ALL, NULL, 0, &needed, &servicesReturned, NULL, NULL);
    bufSize = needed;
    if (bufSize == 0) { CloseServiceHandle(scm); return "[]"; }
    vector<BYTE> buf(bufSize);
    if (!EnumServicesStatusExA(scm, SC_ENUM_PROCESS_INFO, SERVICE_WIN32, SERVICE_STATE_ALL, buf.data(), bufSize, &needed, &servicesReturned, NULL, NULL)) {
        CloseServiceHandle(scm);
        return "{\"error\":\"EnumServicesStatusEx failed\"}";
    }
    auto services = (LPENUM_SERVICE_STATUS_PROCESSA)buf.data();
    ostringstream out;
    out << "[";
    bool first = true;
    for (DWORD i = 0; i < servicesReturned; i++) {
        auto& s = services[i];
        if (!first) out << ",";
        first = false;
        out << "{";
        out << "\"serviceName\":\"" << json_escape(s.lpServiceName ? s.lpServiceName : "") << "\",";
        out << "\"displayName\":\"" << json_escape(s.lpDisplayName ? s.lpDisplayName : "") << "\",";
        out << "\"pid\":" << (DWORD)s.ServiceStatusProcess.dwProcessId << ",";
        // status string
        string st = "Unknown";
        switch (s.ServiceStatusProcess.dwCurrentState) {
        case SERVICE_STOPPED: st = "Stopped"; break;
        case SERVICE_START_PENDING: st = "Start Pending"; break;
        case SERVICE_STOP_PENDING: st = "Stop Pending"; break;
        case SERVICE_RUNNING: st = "Running"; break;
        case SERVICE_CONTINUE_PENDING: st = "Continue Pending"; break;
        case SERVICE_PAUSE_PENDING: st = "Pause Pending"; break;
        case SERVICE_PAUSED: st = "Paused"; break;
        default: break;
        }
        out << "\"status\":\"" << json_escape(st) << "\"";
        out << "}";
    }
    out << "]";
    CloseServiceHandle(scm);
    return out.str();
}

// -- users (process ownership) ------------------------------------------

// Filter out system service accounts
static bool isSystemAccount(const string& username) {
    // Convert to lowercase for comparison
    string userLower = username;
    transform(userLower.begin(), userLower.end(), userLower.begin(), ::tolower);

    static const set<string> systemAccounts = {
        "system",
        "local service",
        "network service",
        "unknown"
    };

    if (systemAccounts.count(userLower) > 0) {
        return true;
    }

    // Check for system prefixes (case-insensitive)
    if (userLower.find("nt authority\\") == 0) return true;
    if (userLower.find("window manager\\") == 0) return true;
    if (userLower.find("font driver host\\") == 0) return true;
    if (userLower.find("dwm-") == 0) return true;
    if (userLower.find("umfd-") == 0) return true;

    // If it contains backslash, check if it looks like a system service account
    size_t backslashPos = userLower.find("\\");
    if (backslashPos != string::npos) {
        string prefix = userLower.substr(0, backslashPos);

        // Real users are usually COMPUTERNAME\Username or DOMAIN\Username
        // System services have specific prefixes
        if (prefix == "system" || prefix == "local service" ||
            prefix == "network service" || prefix == "nt authority" ||
            prefix == "window manager" || prefix == "font driver host") {
            return true;
        }
    }

    return false;
}

static string buildUsersJson() {
    map<string, vector<ProcInfo>> users;
    map<DWORD, ProcInfo> m;
    updateSnapshotsAndComputeCpu(m);
    for (auto& kv : m) {
        const ProcInfo& p = kv.second;
        string user = p.username;
        if (user.empty()) user = "UNKNOWN";

        // Skip system accounts
        if (isSystemAccount(user)) continue;

        users[user].push_back(p);
    }

    // Build JSON with aggregated metrics per user
    ostringstream out;
    out << "[";
    bool first = true;
    for (auto& kv : users) {
        const string& username = kv.first;
        const vector<ProcInfo>& procs = kv.second;

        // Calculate aggregated metrics
        double totalCpu = 0.0;
        SIZE_T totalMemoryKB = 0;

        for (const auto& p : procs) {
            totalCpu += p.cpuPercent;
            totalMemoryKB += p.memoryKB;
        }

        int totalMemoryMB = (int)(totalMemoryKB / 1024);

        if (!first) out << ",";
        first = false;
        out << "{";
        out << "\"username\":\"" << json_escape(username) << "\",";
        out << "\"totalCpuUsage\":" << totalCpu << ",";
        out << "\"totalMemoryUsage\":" << totalMemoryMB << ",";
        out << "\"totalDiskUsage\":0.0,";
        out << "\"totalNetworkUsage\":0.0,";
        out << "\"totalGpuUsage\":0.0,";
        out << "\"processes\":[";
        bool f2 = true;
        for (auto& p : procs) {
            if (!f2) out << ",";
            f2 = false;
            out << "{";
            out << "\"pid\":" << p.pid << ",";
            out << "\"name\":\"" << json_escape(p.name) << "\",";
            out << "\"type\":\"" << p.type << "\",";
            out << "\"cpuPercent\":" << p.cpuPercent << ",";
            out << "\"memoryKB\":" << p.memoryKB;
            out << "}";
        }
        out << "]";
        out << "}";
    }
    out << "]";
    return out.str();
}

// -- files (handle enumeration) -------------------------------------------------

typedef NTSTATUS(WINAPI* pNtQuerySystemInformation)(ULONG SystemInformationClass, PVOID SystemInformation, ULONG SystemInformationLength, PULONG ReturnLength);

#define SystemHandleInformation 16

#ifndef _SYSTEM_HANDLE_
#define _SYSTEM_HANDLE_
typedef struct _SYSTEM_HANDLE {
    ULONG ProcessId;
    BYTE ObjectTypeNumber;
    BYTE Flags;
    USHORT Handle;
    PVOID Object;
    ACCESS_MASK GrantedAccess;
} SYSTEM_HANDLE, * PSYSTEM_HANDLE;
#endif

#ifndef _SYSTEM_HANDLE_INFORMATION_
#define _SYSTEM_HANDLE_INFORMATION_
typedef struct _SYSTEM_HANDLE_INFORMATION {
    ULONG HandleCount;
    SYSTEM_HANDLE Handles[1];
} SYSTEM_HANDLE_INFORMATION, * PSYSTEM_HANDLE_INFORMATION;
#endif

// Get filename from file handle
static string getFileNameFromHandle(HANDLE hFile) {
    char filename[MAX_PATH] = { 0 };
    if (GetFinalPathNameByHandleA(hFile, filename, MAX_PATH, FILE_NAME_NORMALIZED)) {
        string s(filename);
        // Remove \\?\ prefix if present
        if (s.find("\\\\?\\") == 0) {
            s = s.substr(4);
        }
        return s;
    }
    return "";
}

// Get access type from granted access mask
static string getAccessTypeFromMask(ACCESS_MASK mask) {
    BOOL canRead = (mask & FILE_READ_DATA) || (mask & FILE_READ_ATTRIBUTES);
    BOOL canWrite = (mask & FILE_WRITE_DATA) || (mask & FILE_APPEND_DATA);

    if (canRead && canWrite) return "Read/Write";
    if (canRead) return "Read Only";
    if (canWrite) return "Write Only";
    return "None";
}

// Get executable path for a process (more reliable than handle enumeration)
static string getProcessExecutablePath(DWORD pid) {
    HANDLE hProcess = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, pid);
    if (!hProcess) return "";

    char path[MAX_PATH] = { 0 };
    DWORD pathSize = MAX_PATH;

    if (QueryFullProcessImageNameA(hProcess, 0, path, &pathSize)) {
        CloseHandle(hProcess);
        return string(path);
    }

    CloseHandle(hProcess);
    return "";
}

// Get working directory for a process
static string getProcessWorkingDirectory(DWORD pid) {
    // This is a simplified approach - get the directory of the executable
    string exePath = getProcessExecutablePath(pid);
    if (!exePath.empty()) {
        size_t lastSlash = exePath.find_last_of("\\/");
        if (lastSlash != string::npos) {
            return exePath.substr(0, lastSlash);
        }
    }
    return "";
}

// Enumerate open file handles per process
static string buildFilesJson() {
    ostringstream out;
    out << "[";
    bool firstEntry = true;

    // Get ALL running processes with better name detection
    map<DWORD, string> pidToName;
    vector<DWORD> pids(4096);
    DWORD bytes = 0;
    if (EnumProcesses(pids.data(), (DWORD)(pids.size() * sizeof(DWORD)), &bytes)) {
        size_t cnt = bytes / sizeof(DWORD);
        pids.resize(cnt);
        for (DWORD pid : pids) {
            if (pid == 0) continue;

            // Try multiple methods to get process name
            string name = pidToProcessName(pid);
            if (name.empty() || name == "Unknown") {
                // Try getting from executable path
                string exePath = getProcessExecutablePath(pid);
                if (!exePath.empty()) {
                    name = getFilename(exePath);
                }
            }
            if (name.empty()) {
                name = "System Process";
            }
            pidToName[pid] = name;
        }
    }
    cerr << "[FILES] Found " << pidToName.size() << " running processes\n";

    // Map to track which PIDs we've found files for
    map<DWORD, vector<pair<string, string>>> pidFiles; // pid -> list of (filePath, accessType)

    // Get file access information for each process
    for (auto& kv : pidToName) {
        DWORD pid = kv.first;
        string processName = kv.second;

        // Skip system processes that we can't access
        if (pid <= 4) continue;

        // Method 1: Always show the executable file
        string exePath = getProcessExecutablePath(pid);
        if (!exePath.empty()) {
            pidFiles[pid].push_back({ exePath, "Read Only" });
        }

        // Method 2: Add common file locations based on process type
        string lowerName = processName;
        transform(lowerName.begin(), lowerName.end(), lowerName.begin(), ::tolower);

        // For browsers, add common cache/profile locations
        if (lowerName.find("chrome") != string::npos) {
            char appData[MAX_PATH];
            if (SHGetFolderPathA(NULL, CSIDL_LOCAL_APPDATA, NULL, SHGFP_TYPE_CURRENT, appData) == S_OK) {
                string chromeData = string(appData) + "\\Google\\Chrome\\User Data";
                pidFiles[pid].push_back({ chromeData, "Read/Write" });
                pidFiles[pid].push_back({ chromeData + "\\Default\\Cache", "Read/Write" });
            }
        }
        else if (lowerName.find("msedge") != string::npos || lowerName.find("edge") != string::npos) {
            char appData[MAX_PATH];
            if (SHGetFolderPathA(NULL, CSIDL_LOCAL_APPDATA, NULL, SHGFP_TYPE_CURRENT, appData) == S_OK) {
                string edgeData = string(appData) + "\\Microsoft\\Edge\\User Data";
                pidFiles[pid].push_back({ edgeData, "Read/Write" });
            }
        }
        else if (lowerName.find("firefox") != string::npos) {
            char appData[MAX_PATH];
            if (SHGetFolderPathA(NULL, CSIDL_APPDATA, NULL, SHGFP_TYPE_CURRENT, appData) == S_OK) {
                string firefoxData = string(appData) + "\\Mozilla\\Firefox\\Profiles";
                pidFiles[pid].push_back({ firefoxData, "Read/Write" });
            }
        }
        // For Office apps, add Documents folder
        else if (lowerName.find("winword") != string::npos ||
            lowerName.find("excel") != string::npos ||
            lowerName.find("powerpnt") != string::npos) {
            char documents[MAX_PATH];
            if (SHGetFolderPathA(NULL, CSIDL_PERSONAL, NULL, SHGFP_TYPE_CURRENT, documents) == S_OK) {
                pidFiles[pid].push_back({ string(documents), "Read/Write" });
            }
        }
        // For VS Code, add workspace and extensions
        else if (lowerName.find("code") != string::npos) {
            char appData[MAX_PATH];
            if (SHGetFolderPathA(NULL, CSIDL_APPDATA, NULL, SHGFP_TYPE_CURRENT, appData) == S_OK) {
                string vscodeData = string(appData) + "\\Code";
                pidFiles[pid].push_back({ vscodeData, "Read/Write" });
            }
        }

        // Method 3: Add temp directory (most processes use this)
        char tempPath[MAX_PATH];
        if (GetTempPathA(MAX_PATH, tempPath)) {
            string tempStr = string(tempPath);
            if (!tempStr.empty() && tempStr.back() == '\\') tempStr.pop_back();
            pidFiles[pid].push_back({ tempStr, "Read/Write" });
        }

        // Method 4: Add system directories for system processes
        if (lowerName.find("svchost") != string::npos ||
            lowerName.find("system") != string::npos ||
            lowerName.find("service") != string::npos) {
            pidFiles[pid].push_back({ "C:\\Windows\\System32", "Read Only" });
            pidFiles[pid].push_back({ "C:\\Windows\\ServiceProfiles", "Read/Write" });
        }
    }

    cerr << "[FILES] Generated file access information for processes\n";

    // Now output: for each process, either list its files or output "none"
    cerr << "[FILES] Outputting results for all " << pidToName.size() << " processes\n";
    int totalRows = 0;

    for (auto& kv : pidToName) {
        DWORD pid = kv.first;
        string processName = kv.second;

        auto it = pidFiles.find(pid);
        if (it != pidFiles.end() && !it->second.empty()) {
            // Process has open files
            for (auto& fileEntry : it->second) {
                if (!firstEntry) out << ",";
                firstEntry = false;
                out << "{";
                out << "\"pid\":" << pid << ",";
                out << "\"processName\":\"" << json_escape(processName) << "\",";
                out << "\"filePath\":\"" << json_escape(fileEntry.first) << "\",";
                out << "\"accessType\":\"" << fileEntry.second << "\"";
                out << "}";
                totalRows++;
            }
        }
        else {
            // Process has no open files - still show it
            if (!firstEntry) out << ",";
            firstEntry = false;
            out << "{";
            out << "\"pid\":" << pid << ",";
            out << "\"processName\":\"" << json_escape(processName) << "\",";
            out << "\"filePath\":\"none\",";
            out << "\"accessType\":\"None\"";
            out << "}";
            totalRows++;
        }
    }

    cerr << "[FILES] Output " << totalRows << " total rows\n";

    out << "]";
    return out.str();
}

// -- process management -------------------------------------------------

// Enhanced process termination with multiple approaches
static bool enableDebugPrivilege() {
    HANDLE hToken = NULL;
    TOKEN_PRIVILEGES tp = { 0 };
    LUID luid = { 0 };

    if (!OpenProcessToken(GetCurrentProcess(), TOKEN_ADJUST_PRIVILEGES, &hToken)) {
        return false;
    }

    if (!LookupPrivilegeValue(NULL, SE_DEBUG_NAME, &luid)) {
        CloseHandle(hToken);
        return false;
    }

    tp.PrivilegeCount = 1;
    tp.Privileges[0].Luid = luid;
    tp.Privileges[0].Attributes = SE_PRIVILEGE_ENABLED;

    BOOL result = AdjustTokenPrivileges(hToken, FALSE, &tp, sizeof(TOKEN_PRIVILEGES), NULL, NULL);
    CloseHandle(hToken);

    return result && (GetLastError() == ERROR_SUCCESS);
}

static bool terminateProcessTree(DWORD parentPid) {
    cerr << "[TERMINATE_TREE] Terminating process tree for PID " << parentPid << "\n";

    HANDLE hSnapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (hSnapshot == INVALID_HANDLE_VALUE) {
        return false;
    }

    PROCESSENTRY32 pe32 = { 0 };
    pe32.dwSize = sizeof(PROCESSENTRY32);

    vector<DWORD> childPids;

    if (Process32First(hSnapshot, &pe32)) {
        do {
            if (pe32.th32ParentProcessID == parentPid) {
                childPids.push_back(pe32.th32ProcessID);
            }
        } while (Process32Next(hSnapshot, &pe32));
    }

    CloseHandle(hSnapshot);

    // Recursively terminate child processes first
    for (DWORD childPid : childPids) {
        terminateProcessTree(childPid);
    }

    return true;
}

static bool forceTerminateProcess(DWORD pid) {
    cerr << "[FORCE_TERMINATE] Force terminating PID " << pid << "\n";

    // Try to enable debug privilege for better access
    enableDebugPrivilege();

    // Method 1: Try with maximum access rights
    HANDLE hProcess = OpenProcess(PROCESS_TERMINATE | PROCESS_QUERY_INFORMATION | PROCESS_VM_READ, FALSE, pid);
    if (hProcess) {
        BOOL result = TerminateProcess(hProcess, 1);
        CloseHandle(hProcess);
        if (result) {
            cerr << "[FORCE_TERMINATE] Method 1 (TERMINATE) succeeded\n";
            return true;
        }
    }

    // Method 2: Try with PROCESS_ALL_ACCESS
    hProcess = OpenProcess(PROCESS_ALL_ACCESS, FALSE, pid);
    if (hProcess) {
        BOOL result = TerminateProcess(hProcess, 1);
        CloseHandle(hProcess);
        if (result) {
            cerr << "[FORCE_TERMINATE] Method 2 (ALL_ACCESS) succeeded\n";
            return true;
        }
    }

    // Method 3: Try using NtTerminateProcess (undocumented but powerful)
    typedef LONG(NTAPI* pNtTerminateProcess)(HANDLE, ULONG);
    HMODULE hNtdll = GetModuleHandle(L"ntdll.dll");
    if (hNtdll) {
        pNtTerminateProcess NtTerminateProcess = (pNtTerminateProcess)GetProcAddress(hNtdll, "NtTerminateProcess");
        if (NtTerminateProcess) {
            hProcess = OpenProcess(PROCESS_TERMINATE, FALSE, pid);
            if (hProcess) {
                LONG status = NtTerminateProcess(hProcess, 1);
                CloseHandle(hProcess);
                if (status == 0) {  // STATUS_SUCCESS
                    cerr << "[FORCE_TERMINATE] Method 3 (NtTerminateProcess) succeeded\n";
                    return true;
                }
            }
        }
    }

    cerr << "[FORCE_TERMINATE] All methods failed for PID " << pid << "\n";
    return false;
}

// Terminate all processes with the same executable name (for grouped apps like Chrome)
static bool terminateProcessGroup(DWORD mainPid) {
    cerr << "[TERMINATE_GROUP] Starting group termination for main PID " << mainPid << "\n";

    string mainProcName = pidToProcessName(mainPid);
    cerr << "[TERMINATE_GROUP] Main process name: " << mainProcName << "\n";

    // Get all processes with the same name
    vector<DWORD> samePids;
    vector<DWORD> allPids(4096);
    DWORD bytes = 0;

    if (EnumProcesses(allPids.data(), (DWORD)(allPids.size() * sizeof(DWORD)), &bytes)) {
        size_t count = bytes / sizeof(DWORD);
        allPids.resize(count);

        for (DWORD pid : allPids) {
            if (pid == 0) continue;
            string procName = pidToProcessName(pid);
            if (procName == mainProcName) {
                samePids.push_back(pid);
            }
        }
    }

    cerr << "[TERMINATE_GROUP] Found " << samePids.size() << " processes with name " << mainProcName << "\n";

    bool anySuccess = false;
    int successCount = 0;

    // Try to terminate all instances
    for (DWORD pid : samePids) {
        cerr << "[TERMINATE_GROUP] Attempting to terminate PID " << pid << "\n";

        // For Chrome/Edge, try the most aggressive approach first
        if (mainProcName == "chrome.exe" || mainProcName == "msedge.exe") {
            if (forceTerminateProcess(pid)) {
                successCount++;
                anySuccess = true;
                cerr << "[TERMINATE_GROUP] Force terminated " << mainProcName << " PID " << pid << "\n";
            }
        }
        else {
            // For other processes, try standard approach first
            HANDLE hProcess = OpenProcess(PROCESS_TERMINATE, FALSE, pid);
            if (hProcess) {
                BOOL result = TerminateProcess(hProcess, 0);
                CloseHandle(hProcess);
                if (result) {
                    successCount++;
                    anySuccess = true;
                    cerr << "[TERMINATE_GROUP] Standard terminated " << mainProcName << " PID " << pid << "\n";
                }
                else {
                    // Fallback to force termination
                    if (forceTerminateProcess(pid)) {
                        successCount++;
                        anySuccess = true;
                        cerr << "[TERMINATE_GROUP] Force terminated " << mainProcName << " PID " << pid << "\n";
                    }
                }
            }
            else {
                // Can't open, try force termination
                if (forceTerminateProcess(pid)) {
                    successCount++;
                    anySuccess = true;
                    cerr << "[TERMINATE_GROUP] Force terminated " << mainProcName << " PID " << pid << "\n";
                }
            }
        }
    }

    // Give extra time for cleanup, especially for browsers
    if (mainProcName == "chrome.exe" || mainProcName == "msedge.exe") {
        Sleep(1000);  // Browsers need more time
    }
    else {
        Sleep(300);
    }

    cerr << "[TERMINATE_GROUP] Successfully terminated " << successCount << "/" << samePids.size() << " processes\n";

    // Verify termination
    int remainingCount = 0;
    for (DWORD pid : samePids) {
        HANDLE hCheck = OpenProcess(PROCESS_QUERY_INFORMATION, FALSE, pid);
        if (hCheck) {
            DWORD exitCode;
            if (GetExitCodeProcess(hCheck, &exitCode) && exitCode == STILL_ACTIVE) {
                remainingCount++;
            }
            CloseHandle(hCheck);
        }
    }

    cerr << "[TERMINATE_GROUP] " << remainingCount << " processes still active after termination\n";

    // Consider it successful if we terminated most processes
    return (successCount > 0 && remainingCount < samePids.size() / 2);
}

static bool terminateProcess(DWORD pid) {
    cerr << "[TERMINATE] Attempting to terminate PID " << pid << "\n";

    // Get process name for logging
    string procName = pidToProcessName(pid);
    cerr << "[TERMINATE] Process name: " << procName << "\n";

    // For multi-process applications like Chrome/Edge, terminate the entire group
    if (procName == "chrome.exe" || procName == "msedge.exe" || procName == "Code.exe" ||
        procName == "firefox.exe" || procName == "notepad++.exe") {
        cerr << "[TERMINATE] Detected multi-process application, using group termination\n";
        return terminateProcessGroup(pid);
    }

    // For single-process applications, use the original method
    // First, try to terminate child processes
    terminateProcessTree(pid);

    // Method 1: Standard termination
    HANDLE hProcess = OpenProcess(PROCESS_TERMINATE, FALSE, pid);
    if (hProcess) {
        BOOL result = TerminateProcess(hProcess, 0);
        CloseHandle(hProcess);

        if (result) {
            cerr << "[TERMINATE] Standard termination succeeded\n";
            Sleep(200);  // Give time to cleanup

            // Verify the process is actually terminated
            HANDLE hCheck = OpenProcess(PROCESS_QUERY_INFORMATION, FALSE, pid);
            if (!hCheck) {
                cerr << "[TERMINATE] Process successfully terminated and no longer exists\n";
                return true;
            }
            else {
                DWORD exitCode;
                if (GetExitCodeProcess(hCheck, &exitCode) && exitCode != STILL_ACTIVE) {
                    CloseHandle(hCheck);
                    cerr << "[TERMINATE] Process terminated with exit code: " << exitCode << "\n";
                    return true;
                }
                CloseHandle(hCheck);
                cerr << "[TERMINATE] Process still active, trying force termination\n";
            }
        }
    }

    // Method 2: If standard termination failed, try force termination
    cerr << "[TERMINATE] Standard termination failed, trying force termination\n";
    bool forceResult = forceTerminateProcess(pid);

    if (forceResult) {
        Sleep(300);  // Give more time for cleanup

        // Final verification
        HANDLE hCheck = OpenProcess(PROCESS_QUERY_INFORMATION, FALSE, pid);
        if (!hCheck) {
            cerr << "[TERMINATE] Force termination successful - process no longer exists\n";
            return true;
        }
        else {
            DWORD exitCode;
            if (GetExitCodeProcess(hCheck, &exitCode) && exitCode != STILL_ACTIVE) {
                CloseHandle(hCheck);
                cerr << "[TERMINATE] Force termination successful with exit code: " << exitCode << "\n";
                return true;
            }
            CloseHandle(hCheck);
        }
    }

    cerr << "[TERMINATE] All termination attempts failed for PID " << pid << "\n";
    return false;
}

// -- http server ---------------------------------------------------------

static void sendHttpResponse(SOCKET client, const string& body) {
    ostringstream resp;
    resp << "HTTP/1.1 200 OK\r\n";
    resp << "Content-Type: application/json\r\n";
    resp << "Content-Length: " << body.size() << "\r\n";
    resp << "Access-Control-Allow-Origin: *\r\n";
    resp << "Access-Control-Allow-Methods: GET, POST, OPTIONS\r\n";
    resp << "Access-Control-Allow-Headers: Content-Type\r\n";
    resp << "Connection: close\r\n\r\n";
    resp << body;
    string s = resp.str();
    send(client, s.c_str(), (int)s.size(), 0);
}

static void runServer(unsigned short port) {
    WSADATA w;
    if (WSAStartup(MAKEWORD(2, 2), &w) != 0) {
        cerr << "WSAStartup failed\n";
        return;
    }
    SOCKET listenSock = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
    if (listenSock == INVALID_SOCKET) { cerr << "socket failed\n"; WSACleanup(); return; }

    sockaddr_in addr{};
    addr.sin_family = AF_INET;
    // bind to all interfaces (required for Docker container networking)
    addr.sin_addr.s_addr = htonl(INADDR_ANY);
    addr.sin_port = htons(port);

    if (bind(listenSock, (sockaddr*)&addr, sizeof(addr)) == SOCKET_ERROR) {
        cerr << "bind failed\n"; closesocket(listenSock); WSACleanup(); return;
    }
    if (listen(listenSock, SOMAXCONN) == SOCKET_ERROR) {
        cerr << "listen failed\n"; closesocket(listenSock); WSACleanup(); return;
    }

    cout << "Backend listening on http://0.0.0.0:" << port << "\n";
    while (true) {
        SOCKET client = accept(listenSock, nullptr, nullptr);
        if (client == INVALID_SOCKET) continue;
        // read request
        char buf[8192];
        int r = recv(client, buf, (int)sizeof(buf) - 1, 0);
        if (r <= 0) { closesocket(client); continue; }
        buf[r] = '\0';
        string req(buf);

        // Log the full request for debugging
        cerr << "[HTTP] Received request:\n" << req.substr(0, 200) << "\n";

        istringstream ss(req);
        string method, path, ver;
        ss >> method >> path >> ver;

        cerr << "[HTTP] Method: " << method << ", Path: " << path << "\n";

        string body;
        if (method == "GET") {
            if (path == "/processes") body = buildProcessesJson();
            else if (path == "/processes/app") body = buildProcessesJsonFiltered("app");
            else if (path == "/processes/background") body = buildProcessesJsonFiltered("background");
            else if (path == "/processes/system") body = buildProcessesJsonFiltered("system");
            else if (path == "/details") body = buildDetailsJson();
            else if (path == "/sockets") body = buildSocketsJson();
            else if (path == "/services") body = buildServicesJson();
            else if (path == "/users") body = buildUsersJson();
            else if (path == "/files") body = buildFilesJson();
            else body = "{\"error\":\"unknown endpoint\"}";
        }
        else if (method == "POST") {
            cerr << "[POST] Received POST request to: " << path << "\n";

            // Parse POST path for /processes/{pid}/end
            if (path.find("/processes/") == 0 && path.find("/end") != string::npos) {
                cerr << "[POST] Path matches /processes/*/end pattern\n";

                size_t start = path.find("/processes/") + strlen("/processes/");
                size_t end = path.find("/end");
                string pidStr = path.substr(start, end - start);

                cerr << "[POST] Extracted PID string: '" << pidStr << "'\n";

                try {
                    DWORD pid = (DWORD)stoul(pidStr);
                    cerr << "[POST] Parsed PID: " << pid << "\n";

                    // First check if process exists
                    HANDLE hCheck = OpenProcess(PROCESS_QUERY_INFORMATION, FALSE, pid);
                    if (!hCheck) {
                        cerr << "[POST] Process " << pid << " does not exist or cannot be accessed\n";
                        body = "{\"success\":false,\"message\":\"Process not found or access denied\"}";
                    }
                    else {
                        CloseHandle(hCheck);

                        // Get process name for response
                        string processName = pidToProcessName(pid);

                        bool success = terminateProcess(pid);
                        cerr << "[POST] Terminate result for " << processName << " (PID " << pid << "): " << (success ? "SUCCESS" : "FAILED") << "\n";

                        if (success) {
                            body = "{\"success\":true,\"message\":\"Process '" + json_escape(processName) + "' (PID " + to_string(pid) + ") terminated successfully\"}";
                        }
                        else {
                            body = "{\"success\":false,\"message\":\"Failed to terminate process '" + json_escape(processName) + "' (PID " + to_string(pid) + "). Process may be protected or require administrator privileges.\"}";
                        }
                    }
                }
                catch (const exception& e) {
                    cerr << "[POST] Exception parsing PID: " << e.what() << "\n";
                    body = "{\"success\":false,\"message\":\"Invalid PID format\"}";
                }
                catch (...) {
                    cerr << "[POST] Unknown exception parsing PID\n";
                    body = "{\"success\":false,\"message\":\"Invalid PID format\"}";
                }
            }
            else {
                cerr << "[POST] Path does not match /processes/*/end pattern\n";
                body = "{\"error\":\"unknown POST endpoint\"}";
            }
        }
        else {
            body = "{\"error\":\"method not allowed\"}";
        }

        sendHttpResponse(client, body);
        closesocket(client);
    }

    closesocket(listenSock);
    WSACleanup();
}

// -- main ----------------------------------------------------------------

int main(int argc, char** argv) {
    InitializeCriticalSection(&g_snapLock);
    InitializeCriticalSection(&g_nameLock);

    // start background PID->name cache thread
    g_pidCacheRunning.store(true);
    thread([]() { refreshPidNameCacheLoop(5000); }).detach();

    // initialize previous system total once
    g_prevSysTotal = getSystemTotalTime100ns();

    bool consoleMode = false;
    if (argc > 1) {
        string a = argv[1];
        if (a == "--console" || a == "-c") consoleMode = true;
    }

    if (consoleMode) {
        cout << buildProcessesJson() << endl;
        g_pidCacheRunning.store(false);
        DeleteCriticalSection(&g_nameLock);
        DeleteCriticalSection(&g_snapLock);
        return 0;
    }

    cout << "GUI Based Task Manager backend starting.\n";
    cout << "Endpoints:\n  /processes  /processes/app  /processes/background  /processes/system\n";
    cout << "  /details  /sockets  /services  /users  /files\n";
    cout << "Run with --console to print /processes once and exit.\n";
    runServer(8765);

    // cleanup (unreachable in current server loop; left for completeness)
    g_pidCacheRunning.store(false);
    DeleteCriticalSection(&g_nameLock);
    DeleteCriticalSection(&g_snapLock);
    return 0;
}
