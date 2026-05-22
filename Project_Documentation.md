# VSS Lab Project Documentation — Dockerized Windows Task Manager

**Course**: Virtual System and Services Lab (Spring 2026)
**Instructor**: Ms. Bibi Amna
**Project**: GUI Based Task Manager — Dockerized Application
**Group Members**: Huzaifa, Danish, [Add names]
**Deadline**: 22nd May 2026

---

## Table of Contents

1. [Project Scenario](#1-project-scenario)
2. [Application Overview](#2-application-overview)
3. [Technology Stack](#3-technology-stack)
4. [System Architecture](#4-system-architecture)
5. [Prerequisites and Setup](#5-prerequisites-and-setup)
6. [Updates Made to the Application](#6-updates-made-to-the-application)
7. [Docker Implementation](#7-docker-implementation)
8. [Problems Faced and Solutions](#8-problems-faced-and-solutions)
9. [Lessons Learned](#9-lessons-learned)
10. [VMware Integration Concepts](#10-vmware-integration-concepts)
11. [Azure Deployment Concepts](#11-azure-deployment-concepts)
12. [Docker Concepts Demonstrated](#12-docker-concepts-demonstrated)
13. [Final Architecture and Running Instructions](#13-final-architecture-and-running-instructions)
14. [Docker Images and Tags](#14-docker-images-and-tags)
15. [Testing and Verification](#15-testing-and-verification)
16. [Troubleshooting](#16-troubleshooting)
17. [References](#17-references)
18. [Implementation Summary](#18-implementation-summary)
19. [GUI Overview](#19-gui-overview-screens-and-navigation)
20. [Future Enhancements](#20-future-enhancements)
21. [Conclusion](#21-conclusion)

---

## 1. Project Scenario

### 1.1 Overview

Microsoft's built-in **Windows Task Manager** (`taskmgr.exe`) is the standard tool for monitoring system processes, performance, and services on Windows. However, it has several limitations — it is a native Win32 application with no web interface, no container support, no per-process network socket visibility, and no file access tracking.

Our project builds a **modern replacement** from scratch — a **GUI Based Task Manager** — that improves upon the original Windows Task Manager with new features and Docker containerization. The application consists of two microservices:

1. **Backend Service**: A C++ Windows API-based system monitoring engine that collects real-time data about running processes, network connections, file access, system services, and user accounts. It exposes a REST API over HTTP on port 8765.
2. **Frontend Service**: A Flutter Web application that provides a modern, Material Design 3 user interface for visualizing system data and performing actions like process termination, service management, and security monitoring.

### 1.2 Problem Statement — Limitations of the Original Windows Task Manager

The original **Windows Task Manager** (`taskmgr.exe`) by Microsoft, while functional, has several shortcomings that our project addresses:

| Limitation | Impact |
|------------|--------|
| **No network socket visibility** | Cannot see which processes have open network connections or their remote addresses |
| **No file access tracking** | Cannot see which files a process has opened or locked |
| **Native-only UI** | Only works on Windows — no web access, no remote monitoring |
| **No Docker/container support** | Cannot be deployed in a containerized environment |
| **Single termination method** | Limited ability to terminate protected or stubborn processes |
| **No service management** | Cannot start/stop services from the Task Manager interface |
| **No cross-platform access** | Cannot be accessed from a browser or mobile device |

### 1.3 Solution Approach — What We Built

We solved these problems by building a **completely new two-tier Task Manager application** with:

1. **A C++ backend** that uses the same Win32 APIs as Windows Task Manager, but exposes data via a REST API
2. **A Flutter Web frontend** with Material Design 3 UI — accessible from any browser
3. **New features** not found in the original: Sockets tab, Files tab, multi-method process termination, service management
4. **Docker containerization** of the frontend for portable deployment

By containerizing our application, we achieve:

| Benefit | Description |
|---------|-------------|
| **Consistent environment** | Docker containers provide identical runtime environments regardless of host |
| **Simplified deployment** | Single `docker-compose up` command starts the entire stack |
| **Isolation** | Each service runs in its own container with resource limits |
| **Orchestration readiness** | Can be deployed to Docker Swarm, Kubernetes, or Azure Container Instances |
| **Version control** | Docker images tagged with version numbers for release management |
| **Documentation as code** | Dockerfiles and docker-compose serve as executable documentation |

### 1.4 Need for Containerization (Why Docker?)

Our newly built application also needed Docker containerization to solve deployment challenges:

| Challenge | Impact |
|------------|--------|
| **Manual compilation needed** | Every deployment requires Visual Studio + Flutter SDK installed |
| **DLL dependency risk** | Debug builds need Microsoft Visual C++ DLLs not on clean systems |
| **No version management** | No way to track which version is deployed or roll back |
| **Single-machine bound** | Cannot be deployed to cloud, VM, or another machine without full re-setup |
| **No isolation** | Backend and frontend run on the same process space |
| **No orchestration** | Cannot scale, monitor, or manage as a service |

Docker solves all of these by packaging each component into a portable, versioned, isolated container image.

### 1.5 Project Scope

**In Scope:**

| Area | Coverage |
|------|----------|
| **Backend Containerization** | Dockerfile created for Windows container build (taskmgr-backend:v1.0) |
| **Frontend Containerization** | Dockerfile for nginx:alpine Linux container (taskmgr-frontend:v2.0) |
| **Multi-service Orchestration** | Docker Compose with frontend service definition and backend documentation |
| **Code Modifications** | CORS headers, bind address change, static CRT linking for container compatibility |
| **Flutter Web Deployment** | Frontend built as a web application for container-based serving |
| **Hybrid Architecture** | Backend runs natively (required by Win32 API), frontend runs in Docker |
| **Documentation** | Full project documentation including architecture, problems faced, VMware, Azure |
| **Additional Features** | Sockets tab, Files tab, Flutter web UI, multi-method termination, service management |

**Out of Scope:**
- Running the backend inside a container on Windows 10 (not possible due to Hyper-V isolation — see Problem 7)
- Cross-platform backend (requires Windows kernel APIs)
- Authentication/authorization (designed for local system use only)
- Production deployment to Azure (documented conceptually only)

### 1.6 Key Architectural Challenge

The backend is built with Windows-native Win32 API calls (`EnumProcesses`, `OpenProcess`, `GetExtendedTcpTable`, `OpenSCManager`, `NtQuerySystemInformation`, etc.) that require **direct access to the Windows kernel's object manager and process subsystem**. This creates a fundamental constraint:

> **The backend MUST run on a Windows kernel that has access to the host's system processes.**
> Containers, by design, provide process and kernel isolation, which prevents the backend from seeing host processes.

This constraint shaped our entire Docker architecture and led to the final hybrid solution (see Section 8 for full details).

---

## 2. Application Overview

### 2.1 What the Application Does

This project is a fully featured **GUI-based Windows Task Manager** — a replacement and enhancement of the built-in Windows Task Manager (`taskmgr.exe`). It provides real-time monitoring and management of system processes, network connections, file access, services, and user accounts.

The original Windows Task Manager is a native Win32 application limited to running directly on Windows. Our version rebuilds it as a **two-tier web application**:

- **C++ Backend**: Collects all system data using Windows API calls (same APIs Windows itself uses) and exposes it via a REST API.
- **Flutter Web Frontend**: A modern, cross-platform UI with Material Design 3 styling that runs in any browser.

### 2.2 Original vs Our Application

| Aspect | Windows Task Manager (taskmgr.exe) | Our Application |
|--------|-----------------------------------|-----------------|
| **Architecture** | Native Win32 (single process) | Two-tier (C++ backend + Web frontend) |
| **UI Framework** | Windows native (Win32/WTL) | Flutter Web (Material Design 3) |
| **Platform** | Windows only | Any device with a browser (via container) |
| **Process views** | Processes, Performance, App history, Startup, Users, Details, Services | Processes (grouped), Details, Sockets, Files, Services, Users |
| **Additional tabs** | — | **Sockets** — real-time network connections |
| | | **Files** — per-process file access tracking |
| **Deployment** | Manual install | Docker container + native backend |
| **Termination** | Single method | Standard, Force, NtTerminateProcess, privilege escalation |

### 2.3 Features

The GUI Based Task Manager provides comprehensive system monitoring capabilities:

| Feature | Description |
|---------|-------------|
| **Process Monitoring** | Real-time CPU usage, memory consumption, status display |
| **Intelligent Process Grouping** | Groups processes by executable name (e.g., "Chrome (8)" with aggregated metrics) |
| **Process Classification** | Automatically categorizes processes as App, System, or Background |
| **Multi-Method Termination** | Terminates processes using Standard, Force, or NtTerminateProcess methods |
| **Protected Process Termination** | Can terminate protected browsers (Chrome, Edge) using privilege escalation |
| **UAC Virtualization Detection** | Identifies elevated vs standard processes with virtualization status |
| **Network Socket Monitoring** | Real-time TCP/UDP connection tracking with security filtering |
| **File Access Tracking** | Monitors which files each process has open, with intelligent application-specific paths |
| **Service Management** | List, start, stop, and monitor Windows services |
| **User Monitoring** | Processes grouped by user account with aggregated resource metrics |
| **Security-Focused Filtering** | Sockets tab only shows ESTABLISHED external connections (filters out localhost, loopback) |

### 2.4 Additional Features (Beyond Windows Task Manager)

Our application extends beyond the standard Windows Task Manager with several unique features:

#### 2.4.1 Sockets Tab — Real-Time Network Monitoring

**What it does**: Displays all active TCP/UDP network connections on the system, including:
- Local and remote IP addresses and ports
- Connection state (ESTABLISHED, LISTEN, TIME_WAIT, etc.)
- Process ID and name owning each connection
- Security filtering — only shows ESTABLISHED external connections (filters out localhost, loopback, and non-ESTABLISHED states by default)

**How it works**: The C++ backend calls `GetExtendedTcpTable()` and `GetExtendedUdpTable()` Windows APIs to enumerate all network connections. It then cross-references each connection's PID with the process name cache to display the owning application. The frontend's SocketsScreen renders this data in a paginated table with expandable details.

**Why it's useful**: Unlike Windows Task Manager's Performance tab (which only shows aggregate network graphs), our Sockets tab shows every individual connection with its owning process — similar to `netstat -b` but with a real-time UI.

#### 2.4.2 Files Tab — Per-Process File Access Tracking

**What it does**: Shows which files and directories each process has opened or locked, organized by process. The Backend uses multiple methods to gather this information:
- **Method 1**: Attempts to open each process and query its file handles using `NtQueryInformationProcess` / `NtQueryObject`
- **Method 2**: Falls back to application-specific file paths based on process type (e.g., Chrome -> `%LOCALAPPDATA%\Google\Chrome\User Data`, VS Code -> `%APPDATA%\Code`)
- **Method 3**: Adds system directories for system processes
- **Method 4**: Adds well-known paths for common applications

The FilesScreen displays processes grouped by type (App, System, Background) with expandable sections showing file paths and access patterns.

**Why it's useful**: The standard Windows Task Manager does not show file access at all. Our implementation provides insight into which files processes are using — helpful for debugging file locks, identifying malware, or understanding application behavior.

#### 2.4.3 Modern Flutter Web Frontend

**What it is**: The entire user interface is built with **Flutter Web** using Material Design 3 (M3), providing:
- Responsive layout that works on any screen size
- Six tabbed views with smooth navigation
- Interactive data tables with sorting and expandable rows
- Context menus for actions (end task, start/stop service)
- Real-time visual indicators (CPU usage bars, status badges)
- Cross-platform — works in Chrome, Edge, Firefox, and any modern browser

**Why we built it this way**: A Flutter Web frontend is container-ready — it compiles to static HTML/JS/CSS that any web server can serve. This enabled us to containerize the frontend in a lightweight nginx:alpine container, demonstrating Docker concepts while keeping the backend native.

#### 2.4.4 Intelligent Process Grouping

**What it does**: Instead of listing every process individually, the application groups processes by executable name. For example, Chrome typically runs 8+ separate processes — our UI shows them as a single "Chrome (8)" entry with aggregated CPU and memory metrics. Expanding the group shows each individual PID with its specific resource usage.

**How it works**: The backend collects all processes via `EnumProcesses()`, then groups them in the JSON response by executable name. The frontend renders grouped entries as expandable cards.

#### 2.4.5 Multi-Method Process Termination

**What it does**: Provides three termination methods with automatic fallback:
1. **Standard** (`TerminateProcess`) — works for most user applications
2. **Force** (`TerminateProcess` with debug privilege) — for protected processes
3. **NtTerminateProcess** — direct system call termination for stubborn processes

For browsers (Chrome, Edge), a special privilege escalation sequence is used:
- Enable `SeDebugPrivilege`
- Open process with `PROCESS_TERMINATE | PROCESS_QUERY_INFORMATION`
- If fails, retry with `PROCESS_CREATE_THREAD | PROCESS_VM_OPERATION` for remote thread injection

#### 2.4.6 Service Management UI

**What it does**: Lists all Windows services with their current status (Running, Stopped, Paused). Users can start or stop services from the UI via the Context Menu. The backend uses `OpenSCManager()`, `EnumServicesStatusEx()`, `StartService()`, and `ControlService()` Win32 APIs.

**Why it's useful**: Faster than navigating the Services MMC snap-in (`services.msc`). The UI shows services in a clean table format with a contextual action menu.

### 2.5 API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/processes` | All processes grouped by executable |
| GET | `/processes/app` | Application processes only |
| GET | `/processes/background` | Background processes only |
| GET | `/processes/system` | System processes only |
| GET | `/details` | Detailed process information including UAC status |
| GET | `/sockets` | Active network connections (security-filtered) |
| GET | `/files` | File access information per process |
| GET | `/services` | Windows services with current status |
| GET | `/users` | User accounts with aggregated process details |
| POST | `/processes/{pid}/end` | Terminate a process by its PID |
| POST | `/services/{name}/start` | Start a stopped service |
| POST | `/services/{name}/stop` | Stop a running service |

### 2.6 Data Flow

1. User opens the Flutter Web UI in their browser
2. When navigating to a tab, Flutter's `ApiService` makes HTTP GET requests to the backend
3. The C++ backend collects system data via Windows API calls
4. Backend formats data as JSON and returns it in the HTTP response
5. Flutter deserializes the JSON into model objects (Process, SocketConnection, etc.)
6. The UI renders the data in tables, cards, and expandable sections
7. User actions (e.g., "End Task") send POST requests back to the backend
8. Backend executes the action and returns a success/failure response
9. UI updates to reflect the change (refreshes data, shows snackbar notification)

### 2.7 Problems in the Original — Windows Task Manager (taskmgr.exe)

The original **Windows Task Manager** (`taskmgr.exe`) developed by Microsoft has been the standard system monitoring tool since Windows NT 4.0. However, it has several inherent limitations:

| Problem | Description |
|---------|-------------|
| **No network socket visibility** | Cannot see which processes own specific TCP/UDP connections or their remote addresses/ports |
| **No file access tracking** | Cannot see which files or directories a process has opened or locked |
| **Native Win32 only** | Runs only on Windows — no web interface, no remote access, no browser support |
| **No Docker support** | Cannot be containerized — designed as a native desktop app only |
| **Single termination method** | Uses only `TerminateProcess` — cannot handle protected or stubborn processes |
| **No service management** | The "Services" tab is read-only — cannot start or stop services from Task Manager |
| **Limited grouping** | Groups processes but does not show aggregated CPU/memory per application group |
| **No user-centric view** | Cannot see all processes grouped by user account with aggregated metrics |
| **Not extensible** | Closed-source — cannot add new features or modify behavior |
| **No API** | No REST API — data cannot be consumed by other tools or web dashboards |

### 2.8 Objectives of Our Application (vs Windows Task Manager)

Our application was built from scratch to address all the limitations of the original Windows Task Manager and introduce major new capabilities:

| Objective | How It Was Achieved |
|-----------|-------------------|
| **Replace Windows Task Manager** | Built a two-tier app (C++ backend + Flutter frontend) using the same Win32 APIs |
| **Add network socket monitoring** | Built a Sockets tab showing real-time TCP/UDP connections per process |
| **Add file access tracking** | Built a Files tab with per-process file path detection |
| **Enable web access** | Built the frontend in Flutter Web — runs in any browser, not just Windows |
| **Dockerize the application** | Created Dockerfiles for frontend and backend, docker-compose for orchestration |
| **Enable cross-origin web access** | Added CORS headers (`Access-Control-Allow-Origin: *`) to the backend |
| **Make backend container-ready** | Changed bind address to `0.0.0.0`, compiled Release with static CRT (`/MT`) |
| **Improve the UI** | Built with Material Design 3, responsive layout, context menus |
| **Implement multi-method termination** | Added 3 termination methods + privilege escalation for protected browsers |
| **Add service management** | Added start/stop functionality for Windows services from the UI |

---

## 3. Technology Stack

### 3.1 Frontend

| Technology | Version | Purpose |
|------------|---------|---------|
| **Flutter** | 3.x (SDK ^3.9.0) | Cross-platform UI framework |
| **Dart** | 3.x | Programming language |
| **Material Design 3** | — | UI component library and design system |
| **http package** | ^1.0.0 | REST API client for backend communication |

**Frontend Code Organization** (`frontend/lib/`):

| Directory/File | Purpose |
|----------------|---------|
| `main.dart` | Application entry point |
| `app.dart` | App configuration, theme, and tab navigation |
| `models/` | Data models (Process, SocketConnection, FileAccess, Service, User) |
| `screens/` | Six tab screens (Process, Details, Sockets, Files, Services, Users) |
| `services/api_service.dart` | HTTP client for all backend API calls |
| `widgets/` | Reusable UI components (AppHeader, ContextMenu, DataTable, ExpandableSection) |

### 3.2 Backend

| Technology | Version | Purpose |
|------------|---------|---------|
| **C++** | C++20 | Backend programming language |
| **Win32 API** | Windows 10 SDK | System monitoring (processes, sockets, services, files) |
| **Winsock2** | — | Custom HTTP server implementation |
| **Visual Studio 2022 Community** | v143 | Compiler and toolchain |
| **MSBuild** | — | Build system |

**Backend Source** (`backend/`):

| File | Purpose |
|------|---------|
| `task_manager_backend.cpp` | Complete backend (1553 lines) — HTTP server + all system monitoring logic |
| `task_manager_backend.vcxproj` | Visual Studio project file |
| `task_manager_backend.sln` | Visual Studio solution file |

### 3.3 Containerization and Tools

| Tool | Version | Purpose |
|------|---------|---------|
| **Docker Desktop** | 4.64.0 | Container runtime and management |
| **Docker Compose** | v2 | Multi-service orchestration |
| **nginx** | alpine | Frontend container web server (final architecture) |
| **Windows Server Core** | ltsc2019 | Windows container base image (experimental backend build) |
| **Ubuntu** | 22.04 LTS | Linux container base (used in Wine experiments) |
| **Wine** | 6.0+ | Windows compatibility layer (experimental — abandoned) |
| **Python** | 3.11 | HTTP server in Windows frontend container (first build only) |

### 3.4 Communication Protocol

- **Transport**: HTTP/1.1 over TCP
- **Data Format**: JSON (all endpoints return `Content-Type: application/json`)
- **Address**: Backend at `127.0.0.1:8765` (native) or `0.0.0.0:8765` (container)
- **Frontend URL**: `http://localhost:8080`
- **Authentication**: None (designed for local system use)

---

## 4. System Architecture

### 4.1 Final Architecture (Hybrid Approach)

After extensive testing and problem-solving, the final deployment architecture is a **hybrid approach**:

```
┌─────────────────────────────────────────────────────────────────────┐
│                        Windows 10 Host Machine                       │
│                                                                       │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │                     Runs Natively                              │    │
│  │  ┌──────────────────────────────────────────────────────┐   │    │
│  │  │  Backend: task_manager_backend.exe                    │   │    │
│  │  │  Location: backend\x64\Release\task_manager_backend.exe│   │    │
│  │  │  Port: 8765                                           │   │    │
│  │  │  Access: Full Windows API access to host processes     │   │    │
│  │  └──────────────────────────────────────────────────────┘   │    │
│  │                                                               │    │
│  │  ┌──────────────────────────────────────────────────────┐   │    │
│  │  │  Docker Container: Frontend Service                    │   │    │
│  │  │  ┌────────────────────────────────────────────────┐  │   │    │
│  │  │  │  nginx:alpine (Linux container)                  │  │   │    │
│  │  │  │  Serves: Flutter Web UI (static HTML/JS/CSS)    │  │   │    │
│  │  │  │  Port: Container 80 → Host 8080                 │  │   │    │
│  │  │  │  API calls go to http://localhost:8765 (host)   │  │   │    │
│  │  │  └────────────────────────────────────────────────┘  │   │    │
│  │  └──────────────────────────────────────────────────────┘   │    │
│  │                                                               │    │
└─────────────────────────────────────────────────────────────────────┘
                          │
                          ▼
              User's Browser → http://localhost:8080
              (Flutter UI loads, JS calls backend at localhost:8765)
```

### 4.2 Why Hybrid?

The hybrid approach was chosen after three failed containerization attempts:

1. **Linux + Wine** (Attempt 1): Wine cannot see Windows host processes
2. **Windows Container + Hyper-V isolation** (Attempt 2): Hyper-V isolation prevents host process access
3. **Windows Container + Process isolation** (Attempt 3): Process isolation is only available on Windows Server, not Windows 10

The hybrid approach gives us:

| Component | Runs In | Reason |
|-----------|---------|--------|
| Backend | **Native (Windows)** | Needs direct kernel access for process monitoring |
| Frontend | **Docker (nginx:alpine)** | Pure static file serving, benefits from containerization |

### 4.3 What Would Work on Windows Server

If this application were deployed on **Windows Server 2022** (or newer), the backend could run in a **process-isolated Windows container** with host process namespace access. This would require:

```yaml
services:
  backend:
    image: taskmgr-backend:v1.0
    isolation: process  # Only available on Windows Server
    # Would have access to host processes
```

This is documented here for future reference and to demonstrate understanding of Windows container isolation modes.

---

## 5. Prerequisites and Setup

### 5.1 Required Software

| Software | Download | Purpose |
|----------|----------|---------|
| **Docker Desktop** | [docker.com](https://www.docker.com/products/docker-desktop/) | Container runtime |
| **Flutter SDK** | [flutter.dev](https://docs.flutter.dev/get-started/install) | Build Flutter web frontend |
| **Visual Studio 2022 Community** | [visualstudio.microsoft.com](https://visualstudio.microsoft.com/vs/community/) | Compile C++ backend |
| **Git (optional)** | [git-scm.com](https://git-scm.com/) | Version control |

### 5.2 Installation Guide

#### Docker Desktop
```powershell
# 1. Download Docker Desktop from docker.com
# 2. Run the installer — choose WSL 2 backend (default) for Linux containers
#    OR choose Hyper-V/Windows containers for Windows container support
# 3. Launch Docker Desktop and verify:
docker --version
docker-compose --version
docker run hello-world
```

#### Flutter SDK
```powershell
# 1. Download from flutter.dev
# 2. Extract to C:\flutter, add to PATH
# 3. Verify:
flutter doctor
# 4. Enable web platform (if needed):
flutter config --enable-web
```

#### Visual Studio 2022
```powershell
# 1. Download from visualstudio.microsoft.com
# 2. Install "Desktop development with C++" workload
# 3. Verify:
msbuild --version
```

### 5.3 Windows Features (for Windows Containers)

If using Windows containers (requires Docker Desktop with Windows container support):

```powershell
# Run PowerShell as Administrator
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All
# Restart

Enable-WindowsOptionalFeature -Online -FeatureName Containers -All
# Restart

# Switch Docker to Windows containers (via system tray or CLI)
& "C:\Program Files\Docker\Docker\DockerCli.exe" -SwitchWindowsEngine

# Verify
docker info
# Look for: OSType: windows
```

### 5.4 Project Structure — File-by-File Description

```
C:\Users\Huzaifa\Desktop\Windows Task Manager\
│
├── backend/
│   │
│   ├── task_manager_backend.cpp     ← MAIN BACKEND (1553 lines)
│   │   Functions:
│   │   ├── main()                     Entry point — starts HTTP server on port 8765
│   │   ├── startServer()              Creates Winsock socket, binds to 0.0.0.0:8765,
│   │   │                              accepts connections in a loop
│   │   ├── handleClient()             Parses HTTP request, routes to handler by path
│   │   ├── sendHttpResponse()         Sends HTTP response with CORS headers + JSON body
│   │   ├── classifyProcessType()      Classifies process as "app", "system", "background"
│   │   ├── buildProcessesJson()       EnumProcesses → groups by exe name → JSON
│   │   ├── buildProcessesJsonFiltered() Filters processes by type
│   │   ├── buildDetailsJson()         Detailed per-process info (PID, user, CPU, UAC)
│   │   ├── buildSocketsJson()         GetExtendedTcpTable → TCP connections → JSON
│   │   ├── buildFilesJson()           Per-process file paths (NtQueryObject + fallbacks)
│   │   ├── buildServicesJson()        OpenSCManager → EnumServicesStatusEx → JSON
│   │   ├── buildUsersJson()           Processes grouped by user account
│   │   ├── terminateProcessByPid()    Multi-method termination (3 approaches)
│   │   ├── controlService()           Start/stop Windows services
│   │   ├── refreshPidNameCacheLoop()  Background thread: maps PIDs → process names
│   │   └── getProcessUsername()       Retrieves owner username for a PID
│   │
│   ├── task_manager_backend.vcxproj  Visual Studio project — defines build config,
│   │                                  includes libraries (ws2_32, advapi32, etc.),
│   │                                  Release x64 uses /MT (static CRT)
│   │
│   ├── task_manager_backend.sln       Visual Studio solution — references vcxproj
│   │
│   ├── Dockerfile                     Builds Windows container with the backend exe
│   │                                  (documentation only — backend runs natively)
│   │
│   ├── x64/
│   │   ├── Debug/
│   │   │   └── task_manager_backend.exe   Debug build (920 KB, needs DLLs)
│   │   └── Release/
│   │       └── task_manager_backend.exe   Release build (360 KB, static CRT, standalone)
│   │
│   └── lib/ (misplaced — frontend code)
│
├── frontend/
│   │
│   ├── lib/                           ← FLUTTER DART SOURCE
│   │   │
│   │   ├── main.dart                  App entry point — runs Flutter app
│   │   │
│   │   ├── app.dart                   Root widget — MaterialApp with theme, tab scaffold
│   │   │                              Defines 6-tab navigation: Process, Details,
│   │   │                              Sockets, Files, Services, Users
│   │   │
│   │   ├── models/
│   │   │   ├── process.dart           Process model — pid, name, cpu%, memory, type,
│   │   │   │                          processCount, status, username, allPids
│   │   │   ├── socket_connection.dart Socket model — localAddr/port, remoteAddr/port,
│   │   │   │                          state, pid, processName
│   │   │   ├── file_access.dart       FileAccess model — pid, processName, type, files[]
│   │   │   ├── service_model.dart     ServiceModel — name, displayName, status, description
│   │   │   └── user_model.dart        UserModel — username, processes[], totalCpu, totalMem
│   │   │
│   │   ├── screens/
│   │   │   ├── processes_screen.dart  Tab 1: Grouped processes, expandable cards,
│   │   │   │                          context menu with "End Task", "End Force"
│   │   │   ├── details_screen.dart    Tab 2: Flat table of all processes with details
│   │   │   │                          (PID, name, user, CPU, memory, status, UAC)
│   │   │   ├── sockets_screen.dart    Tab 3: Network connections — local/remote IP:port,
│   │   │   │                          state, owning process, security-filtered
│   │   │   ├── files_screen.dart      Tab 4: Per-process file paths, grouped by type
│   │   │   ├── services_screen.dart   Tab 5: Windows services list + start/stop actions
│   │   │   └── users_screen.dart      Tab 6: Processes grouped by user account
│   │   │
│   │   ├── services/
│   │   │   └── api_service.dart       HTTP client — baseUrl = 'http://127.0.0.1:8765'
│   │   │                              Methods for each endpoint:
│   │   │                              → fetchProcesses(type), fetchDetails(),
│   │   │                              → fetchSockets(), fetchFiles(),
│   │   │                              → fetchServices(), fetchUsers(),
│   │   │                              → endProcess(pid), startService(name),
│   │   │                              → stopService(name)
│   │   │
│   │   └── widgets/
│   │       ├── app_header.dart        Reusable header with app icon + title
│   │       ├── context_menu.dart      Popup menu for actions (End Task, Start/Stop)
│   │       ├── data_table_widget.dart Reusable sortable table with column config
│   │       └── expandable_section.dart Collapsible card sections for grouped data
│   │
│   ├── build/web/                     Flutter web build output (compiled HTML/JS/CSS)
│   │                                  index.html, main.dart.js, assets/, icons/
│   │                                  This is what nginx serves in the container
│   │
│   ├── pubspec.yaml                   Flutter dependencies:
│   │                                  → http: ^1.0.0  (REST API client)
│   │                                  → flutter: material design SDK
│   │
│   └── Dockerfile                     FROM nginx:alpine
│                                      COPY build/web /usr/share/nginx/html
│                                      EXPOSE 80
│
├── docker-compose.yml                 Orchestrates frontend service (port 8080:80)
│                                      Backend documented as native dependency
│
├── project_plan.md                    Original project plan with architecture,
│                                      deliverables, timeline, and step-by-step
│
└── Project_Documentation.md           This document — full project documentation
```

---

## 6. Containerization Changes to Our Backend Code

### 6.1 Overview of Changes

When building our application, we designed it to eventually run in containers. The following changes were made to the backend code specifically to enable container deployment:

| # | Change | File | Lines | Purpose |
|---|--------|------|-------|---------|
| 1 | Bind address: `127.0.0.1` → `0.0.0.0` | `task_manager_backend.cpp` | ~1403 | Accept connections from outside container |
| 2 | Added CORS headers | `task_manager_backend.cpp` | ~1385-1387 | Allow cross-origin browser requests |
| 3 | Log message update | `task_manager_backend.cpp` | ~1418 | Accurate logging |
| 4 | Static CRT linking | `task_manager_backend.vcxproj` | ~118 | Remove DLL dependencies for Wine/container |
| 5 | Flutter web build | — | — | Enable web deployment for container |

### 6.2 Change 1: Bind Address

**Problem**: Our initial backend bound to `127.0.0.1` (localhost only), which would prevent connections from outside the container if we ran the backend inside one. We changed it to accept connections from all interfaces.

**Initial Code** (`task_manager_backend.cpp:~1402`):
```cpp
// use InetPtonA instead of deprecated inet_addr
if (InetPtonA(AF_INET, "127.0.0.1", &addr.sin_addr) != 1) {
    cerr << "InetPtonA failed\n";
    closesocket(listenSock);
    WSACleanup();
    return;
}
```

**Final Code**:
```cpp
// bind to all interfaces (required for Docker container networking)
addr.sin_addr.s_addr = htonl(INADDR_ANY);
```

**Why it works**: `INADDR_ANY` (0.0.0.0) tells the socket to accept connections from any network interface, including the Docker NAT gateway that forwards traffic from the host.

### 6.3 Change 2: CORS Headers

**Problem**: The Flutter Web frontend is served from `localhost:8080` but makes API calls to `localhost:8765`. Browsers enforce the **Same-Origin Policy** — since these are different ports, they count as different origins. Without CORS headers, the browser blocks the API requests.

**Initial Code** (`task_manager_backend.cpp:~1380`) — no CORS headers:
```cpp
static void sendHttpResponse(SOCKET client, const string& body) {
    ostringstream resp;
    resp << "HTTP/1.1 200 OK\r\n";
    resp << "Content-Type: application/json\r\n";
    resp << "Content-Length: " << body.size() << "\r\n";
    resp << "Connection: close\r\n\r\n";
    resp << body;
    ...
}
```

**Final Code** — with CORS headers added:
```cpp
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
    ...
}
```

**Why it works**: The `Access-Control-Allow-Origin: *` header tells the browser that any origin is allowed to access this resource. The browser sees this header and allows the JavaScript running on `localhost:8080` to call the API on `localhost:8765`.

### 6.4 Change 3: Static CRT Linking

**Problem**: When compiling in Debug mode, the backend depends on Debug DLLs (`MSVCP140D.dll`, `VCRUNTIME140D.dll`, `ucrtbased.dll`) that are not available in Wine or in Windows Server Core containers. These DLLs are only installed with Visual Studio.

**Solution**: We compiled in **Release x64** mode and added `<RuntimeLibrary>MultiThreaded</RuntimeLibrary>` to the project configuration for static CRT linking.

**Project Configuration**:
```xml
<ItemDefinitionGroup Condition="'$(Configuration)|$(Platform)'=='Release|x64'">
    <ClCompile>
      <WarningLevel>Level3</WarningLevel>
      <FunctionLevelLinking>true</FunctionLevelLinking>
      <IntrinsicFunctions>true</IntrinsicFunctions>
      <SDLCheck>true</SDLCheck>
      <PreprocessorDefinitions>NDEBUG;_CONSOLE;%(PreprocessorDefinitions)</PreprocessorDefinitions>
      <ConformanceMode>true</ConformanceMode>
      <RuntimeLibrary>MultiThreaded</RuntimeLibrary>
    </ClCompile>
    ...
</ItemDefinitionGroup>
```

**Why it works**: `/MT` (MultiThreaded) embeds the C++ runtime library directly into the executable, so there are no external DLL dependencies. The .exe becomes self-contained and can run in any Windows environment.

### 6.5 Change 4: Flutter Web Build

**Why**: We built our frontend in Flutter Web (not Flutter Desktop) specifically so it can be served as static files from a container (nginx:alpine).

**Command**:
```powershell
cd frontend
flutter build web --release
```

**Output**: `frontend/build/web/` — contains `index.html`, `main.dart.js`, assets, and other static files.

---

## 7. Docker Implementation

### 7.1 Frontend Dockerfile

**Location**: `frontend/Dockerfile`

```dockerfile
FROM nginx:alpine
COPY build/web /usr/share/nginx/html
EXPOSE 80
```

**Why nginx:alpine**:
- Alpine Linux base is extremely lightweight (~5 MB)
- nginx is optimized for serving static files
- Zero configuration needed for static content
- No Python, Node.js, or other runtime overhead

**How it works**: When the container starts, nginx automatically serves all files in `/usr/share/nginx/html`. The Flutter web build output (HTML, JS, CSS, assets) is copied into this directory during the Docker build.

### 7.2 Docker Compose Configuration

**Location**: `docker-compose.yml`

```yaml
services:
  frontend:
    build: ./frontend
    ports:
      - "8080:80"

  # Backend runs natively on Windows because it needs direct access to
  # Windows kernel APIs (EnumProcesses, OpenProcess, etc.) to monitor
  # host system processes. Windows containers on Win10 use Hyper-V
  # isolation and cannot see host processes.
  # 
  # Run backend natively: backend\x64\Release\task_manager_backend.exe
  # Backend listens on port 8765
```

**Why only frontend is in docker-compose**:
- The frontend is a pure static file server — perfectly suited for containers
- The backend requires Windows kernel access — cannot be containerized on Windows 10
- See Section 8 for the full technical explanation

### 7.3 Docker Commands

```powershell
# Build the frontend image
docker-compose build frontend

# Tag with version
docker tag windowstaskmanager-frontend:latest taskmgr-frontend:v1.0

# Run frontend container
docker-compose up frontend

# Run in background (detached)
docker-compose up -d frontend

# Stop
docker-compose down

# View logs
docker-compose logs frontend

# Check status
docker-compose ps
```

### 7.4 Backend Native Execution

```powershell
# Compile
cd backend
msbuild task_manager_backend.sln /p:Configuration=Release /p:Platform=x64

# Run
cd x64/Release
.\task_manager_backend.exe
```

The backend prints:
```
GUI Based Task Manager backend starting.
Endpoints:
  /processes  /processes/app  /processes/background  /processes/system
  /details  /sockets  /services  /users  /files
Run with --console to print /processes once and exit.
Backend listening on http://0.0.0.0:8765
```

---

## 8. Problems Faced and Solutions

### 8.1 Introduction

This section documents every major problem encountered during the project, the root cause analysis, attempted solutions, and final resolution. Each problem is described in enough detail that anyone reading this document can understand the technical constraints and reasoning behind our architectural decisions.

---

### Problem 1: Web Frontend API Connection (CORS)

**Category**: Browser Security
**Severity**: Critical (frontend couldn't fetch data)
**Phase**: Initial frontend-backend integration

**Description**:
When the Flutter Web frontend (served from `localhost:8080`) attempted to make HTTP requests to the backend (running on `localhost:8765`), the browser blocked the requests with a CORS error. The browser console showed:
```
Access to XMLHttpRequest at 'http://localhost:8765/processes/app' 
from origin 'http://localhost:8080' has been blocked by CORS policy:
No 'Access-Control-Allow-Origin' header is present on the requested resource.
```

**Root Cause**:
The browser's Same-Origin Policy treats `http://localhost:8080` and `http://localhost:8765` as different origins because they use different ports. By default, JavaScript can only make requests to the same origin it was loaded from.

**Attempted Solutions**:
1. **Nginx reverse proxy**: Configure nginx to proxy `/api/*` requests to the backend — this would make all requests appear to come from the same origin (port 8080). This was the planned solution but added complexity.
2. **Same port**: Serve frontend and backend from the same port — not feasible since they're different technologies.

**Final Solution**:
Added CORS headers to the backend's HTTP response. The `sendHttpResponse()` function in `task_manager_backend.cpp` was modified to include:
```cpp
resp << "Access-Control-Allow-Origin: *\r\n";
resp << "Access-Control-Allow-Methods: GET, POST, OPTIONS\r\n";
resp << "Access-Control-Allow-Headers: Content-Type\r\n";
```

**Why it works**: The `*` value tells the browser to allow requests from any origin. This is safe for a local-only application that runs on a developer's machine. For production, a specific origin would be used instead of `*`.

**Verification**: After recompiling the backend with these headers, the Flutter frontend successfully fetched data from all API endpoints.

**Lesson**: When building web applications that consume APIs from different ports/services, CORS must be handled on the server side. The simplest approach is adding the appropriate headers to HTTP responses.

---

### Problem 2: Backend Crash with Debug DLL Dependencies

**Category**: Software Dependency
**Severity**: Critical (backend wouldn't start)
**Phase**: Container execution

**Description**:
When running the compiled C++ backend inside a container, it immediately exited with error code 53. The container logs showed:
```
0024:err:module:import_dll Library MSVCP140D.dll (which is needed by 
L"Z:\\app\\task_manager_backend.exe") not found
0024:err:module:import_dll Library VCRUNTIME140D.dll (which is needed by 
L"Z:\\app\\task_manager_backend.exe") not found
0024:err:module:import_dll Library ucrtbased.dll (which is needed by 
L"Z:\\app\\task_manager_backend.exe") not found
```

**Root Cause**:
The backend was compiled in **Debug mode**, which links against Debug versions of the Visual C++ runtime libraries. These DLLs have names ending in `D` (e.g., `MSVCP140**D**.dll`, `VCRUNTIME140**D**.dll`, `ucrtbased.dll`). These Debug DLLs are:
- Not included in Windows Server Core container images
- Not available in Wine
- Only installed with Visual Studio on development machines

**Attempted Solutions**:
1. **Copy Debug DLLs to container**: We could manually copy the DLLs from `C:\Program Files\Microsoft Visual Studio\...` but this would be fragile and version-specific.
2. **Install Visual C++ Redistributable in container**: Debug DLLs are not redistributable — only Release DLLs are.

**Final Solution**:
Compiled the backend in **Release mode with static CRT linking**. Two changes were needed:

a) Changed build configuration from Debug to Release:
```powershell
msbuild task_manager_backend.sln /p:Configuration=Release /p:Platform=x64
```

b) Added static runtime linking to the project file (`task_manager_backend.vcxproj`):
```xml
<RuntimeLibrary>MultiThreaded</RuntimeLibrary>
```

This tells the compiler to embed the C++ runtime directly into the executable (`/MT` flag) instead of linking to external DLLs (`/MD` flag).

**Verification**:
- Release build size: 360 KB (vs Debug: 920 KB)
- The Release .exe runs standalone on any Windows system without requiring VC++ Redistributable
- Successfully executed in Windows Server Core container

**Lesson**: Always compile Release builds with static runtime for container deployment. Debug builds have dependencies that don't exist in production/container environments. The `/MT` flag creates a self-contained executable.

---

### Problem 3: Docker Hub Network Timeout

**Category**: Network/Infrastructure
**Severity**: High (build blocked)
**Phase**: Docker image build

**Description**:
The first `docker-compose build` command failed with:
```
failed to do request: Head "https://registry-1.docker.io/v2/library/nginx/manifests/alpine":
net/http: TLS handshake timeout
```

**Root Cause**:
Intermittent network connectivity issue between Docker Desktop and Docker Hub's registry servers. Docker needs to download base images (nginx:alpine, ubuntu:22.04, etc.) from `registry-1.docker.io`.

**Solution**:
Pulled the base images separately before building:
```powershell
docker pull nginx:alpine
docker pull ubuntu:22.04
```

After the images were cached locally, `docker-compose build` succeeded immediately because it used the cached layers.

**Root Cause of Root Cause**: Docker Hub uses a content delivery network (CDN) with multiple mirror servers. The TLS handshake can occasionally time out due to DNS resolution issues or CDN routing. Pulling images separately retries with potentially different CDN endpoints.

**Prevention**: Always pull base images before building if you encounter registry timeouts. Docker caches downloaded layers, so subsequent builds are much faster.

---

### Problem 4: Windows 10 Build / Windows Container Version Mismatch

**Category**: Compatibility
**Severity**: Critical (couldn't pull base image)
**Phase**: Docker image build

**Description**:
When building with `mcr.microsoft.com/windows/servercore:ltsc2022`, the build failed with:
```
no matching manifest for windows(10.0.19045)/amd64 in the manifest list entries
```

**Root Cause**:
Windows container images are **build-specific**. The host Windows version and the container image version must be compatible:
- `ltsc2022` → Windows Server 2022 (build 20348)
- `ltsc2019` → Windows Server 2019 (build 17763)
- Host: Windows 10 22H2 (build 19045)

The user's Windows 10 build 19045 is different from the ltsc2022 build 20348. Windows containers using Hyper-V isolation require the base image to match the host build or be a compatible version.

**Solution**:
Used `mcr.microsoft.com/windows/servercore:ltsc2019` instead, which is based on build 17763 — an older build that is compatible with the host's build 19045 through Hyper-V isolation.

For the Python frontend container, `python:3.11-windowsservercore-1809` was used (matching the ltsc2019 build number).

**Verification**: Both images built successfully with the corrected version tags.

**Lesson**: Windows container base images are version-specific. Always check your host Windows build number (`[System.Environment]::OSVersion.Version`) and select a matching container base image. The pattern is:
- `ltsc2019` / `1809` for builds 17763 (Windows Server 2019)
- `ltsc2022` for builds 20348 (Windows Server 2022 / Windows 11)
- For Windows 10, use the build-specific tag if available, or `ltsc2019` as fallback

---

### Problem 5: Windows Containers Disabled in Docker Installation

**Category**: Software Configuration
**Severity**: Critical (Windows containers unavailable)
**Phase**: Initial setup

**Description**:
When trying to switch Docker Desktop to Windows containers mode, we got:
```
switching to windows engine: windows containers have been disabled for this installation
```

**Root Cause**:
Docker Desktop was installed with the default **WSL 2 backend** (Linux containers only). The Windows container engine component was either not installed or disabled during the initial installation.

Docker Desktop's installer has a `--no-windows-containers` flag that disables Windows container support. Our installation was either run with this flag or the installer detected that Windows Features (Hyper-V, Containers) were not enabled.

**Attempted Solutions**:
1. **Enable Windows Features**: Ran `Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All` and `Enable-WindowsOptionalFeature -Online -FeatureName Containers -All` — required restarts
2. **Re-run installer**: Tried `Docker Desktop Installer.exe install --accept-license --backend=windows` — failed with "Missing package flag" because the installer is a stub
3. **Docker Desktop settings**: Checked `features-overrides.json`, `settings-store.json`, and registry — no configuration could re-enable it without reinstalling

**Final Solution**:
Uninstalled Docker Desktop from Control Panel → Programs and Features, then downloaded a fresh installer from [docker.com](https://www.docker.com/products/docker-desktop/) and reinstalled. During the fresh installation, the installer detected that Hyper-V and Containers features were already enabled (from our earlier steps), so Windows container support was automatically included.

After reinstallation, switching to Windows containers succeeded:
```powershell
docker info
# OSType: windows  ✓
```

**Verification**:
- `docker info` shows `OSType: windows`
- Windows container images could now be pulled and built
- `docker pull mcr.microsoft.com/windows/servercore:ltsc2019` succeeded

**Lesson**: Docker Desktop installations are not easily modified to add Windows container support after the fact. The simplest solution is to enable Windows Features first, then do a fresh Docker Desktop installation. The installer detects the available features and configures accordingly.

---

### Problem 6: Linux + Wine Cannot Monitor Windows Host Processes

**Category**: Fundamental Architecture Limitation
**Severity**: Critical (incorrect data)
**Phase**: Container execution

**Description**:
When running the backend in a Linux container with Wine, the application ran but showed incorrect data:
- Username displayed as `S-1-5-.../root` instead of the actual Windows user
- Only system processes and the backend itself were visible
- User applications (Chrome, VS Code, etc.) were not shown
- Files and sockets showed no data

**Root Cause**:
Wine is a **Windows compatibility layer** that translates Win32 API calls to Linux system calls. When the backend calls `EnumProcesses()`, Wine:
1. Calls Linux's `/proc` filesystem to enumerate processes
2. Returns only the processes running inside the Wine environment
3. Cannot see Windows host processes because it's running on Linux

The same applies to other APIs:
| Windows API | Linux/Wine Behavior |
|-------------|-------------------|
| `EnumProcesses` | Lists only Wine processes, not host processes |
| `OpenProcess` | Can only open processes within the Wine prefix |
| `GetExtendedTcpTable` | Returns empty (no Windows TCP stack) |
| `OpenSCManager` | Fails (no Windows Service Control Manager) |
| `GetProcessUsername` | Returns SID (no Windows security subsystem) |
| `WTSEnumerateSessions` | Returns empty (no Windows Terminal Services) |

**Attempted Solutions**:
1. **Install missing Wine components**: Ran `apt-get install wine32` and configured Wine Gecko — these only affect Wine's internal rendering and COM support, not process enumeration
2. **Use winetricks**: Installing vcrun2022, vcrun2019 — only adds Visual C++ runtime support, doesn't change process enumeration

**Resolution**: This approach was abandoned as fundamentally infeasible. Wine is designed to run Windows applications, not to monitor Windows system processes. The backend needs direct access to the Windows kernel's process subsystem, which Wine cannot provide.

**Lesson**: Wine is useful for running Windows desktop applications on Linux but cannot replace Windows kernel APIs for system monitoring tools. Applications that depend on `EnumProcesses`, `CreateToolhelp32Snapshot`, `WTSEnumerateSessions`, and similar APIs must run on actual Windows.

---

### Problem 7: Windows Container Hyper-V Isolation Cannot See Host Processes

**Category**: Fundamental Architecture Limitation
**Severity**: Critical (incorrect data)
**Phase**: Container execution

**Description**:
When running the backend in a Windows container (Hyper-V isolation mode), the application ran but showed incorrect data:
- Username displayed as `ContainerAdministrator` instead of the actual Windows user
- Only processes within the container were visible
- No host applications were shown

**Root Cause**:
On **Windows 10 and 11**, Windows containers **always use Hyper-V isolation**. This means each container runs in its own lightweight virtual machine with:
- Its own Windows kernel (separate from the host)
- Its own process namespace
- Its own registry
- Its own security subsystem

The backend's Win32 API calls only see processes within this container VM, not processes on the Windows host. This is by design — Hyper-V isolation provides strong security boundaries between containers and the host.

**Comparison of Windows Container Isolation Modes**:

| Feature | Hyper-V Isolation | Process Isolation |
|---------|------------------|------------------|
| **Available on** | Windows 10/11, Windows Server | Windows Server only |
| **Kernel sharing** | No (separate VM) | Yes (shared with host) |
| **Host process visibility** | No | Yes (with config) |
| **Security boundary** | Strong (Hyper-V VM) | Moderate (namespace) |
| **Performance overhead** | Higher | Minimal |

**Attempted Solutions**:
1. **Process isolation flag**: Tried `--isolation=process` — fails on Windows 10 (not supported)
2. **Host process namespace**: Tried `--pid=host` — not supported for Windows containers

**Resolution**: This approach was abandoned as fundamentally infeasible on Windows 10. The application could run with full functionality in a process-isolated container on **Windows Server 2022**, but that was not available.

**Lesson**: The choice between Hyper-V isolation and process isolation is critical when containerizing Windows applications. System monitoring tools that need host OS access must use **process isolation containers on Windows Server**. Windows 10/11 clients can only use Hyper-V isolation, which provides full kernel isolation.

---

### Problem 8: Docker Desktop Installer "Missing Package Flag"

**Category**: Software Tooling
**Severity**: Medium (installation modification failed)
**Phase**: Setup

**Description**:
When trying to modify the existing Docker Desktop installation to add Windows container support via the CLI:
```powershell
& "C:\Program Files\Docker\Docker\Docker Desktop Installer.exe" install --accept-license --backend=windows
```
The installer responded with:
```
Missing package flag
```

**Root Cause**:
The `Docker Desktop Installer.exe` in the installation directory is a **stub installer**. When run, it expects a package argument pointing to the actual installer package (e.g., a `.msi` or full installer `.exe`). It cannot modify the existing installation — it can only perform fresh installations or updates using a downloaded package.

The installer supports:
- `install` — Install Docker Desktop (requires package on command line or in current directory)
- `validate` — Verify current installation

**Solution**:
Since the installer couldn't modify the existing installation, we:
1. Uninstalled Docker Desktop from Control Panel
2. Downloaded a fresh installer from docker.com
3. Reinstalled fresh

The fresh installation automatically detected the already-enabled Hyper-V and Containers Windows features and included Windows container support.

**Alternative (if known at the time)**: Running the official installer from docker.com directly (not the one from the installation directory) and passing `--backend=windows` would have worked.

**Lesson**: The Docker Desktop Installer in the installation directory is a stub for updates. For fresh installations or major configuration changes, download the full installer from docker.com.

---

### Problem 9: Backend Image Cannot Be Built in Linux Container Mode

**Category**: Cross-Platform Compatibility
**Severity**: Medium (affects screenshot/demo only)
**Phase**: Final documentation and presentation

**Description**:
When Docker Desktop is switched to **Linux container mode** (required by the final hybrid architecture where the frontend runs in a lightweight `nginx:alpine` Linux container), the backend Docker image (`taskmgr-backend:v1.0`) cannot be rebuilt or pulled because:

```
$ docker build -t taskmgr-backend:v1.0 ./backend
=> ERROR [internal] load metadata for mcr.microsoft.com/windows/servercore:ltsc2019
failed to solve: mcr.microsoft.com/windows/servercore:ltsc2019: 
no match for platform in manifest: not found
```

**Root Cause**:
Docker Desktop can only run **one container runtime at a time** — either Linux or Windows containers. When in Linux container mode:
1. The Docker engine is configured to pull and run Linux images (x86_64/AMD64 platform)
2. Windows base images (e.g., `mcr.microsoft.com/windows/servercore:ltsc2019`) have the platform `windows/amd64`
3. The Linux-mode Docker engine cannot pull or build Windows images because they use a different operating system and kernel architecture

When switching back to Windows container mode to build the backend image:
1. The existing Linux containers (frontend) must be stopped
2. The engine restarts in Windows mode
3. All Linux images become invisible — only Windows images are shown
4. After building, switching back to Linux mode loses the Windows images again

**Attempted Solutions**:
1. **Separate pull of base image**: Tried `docker pull mcr.microsoft.com/windows/servercore:ltsc2019` in Linux mode — fails with the same platform mismatch error
2. **Dual Docker installations**: Having two Docker instances is not supported — Docker Desktop only runs one engine at a time
3. **Keeping both images visible**: Not possible — `docker images` only shows images matching the current container OS type

**Final Resolution**:
This is an **accepted limitation** of using a hybrid architecture with mixed OS containers. For the presentation:
1. Take a screenshot of `docker images` showing `taskmgr-frontend:v2.0` + pulled public images (hello-world, alpine, nginx:alpine) from Linux mode
2. Take a separate screenshot of `docker images` showing `taskmgr-backend:v1.0` from Windows mode
3. The Project_Documentation.md clearly explains both modes and why the backend cannot run in a container

**Workaround for Live Demo**:
To show both images simultaneously during a live demo:
1. Switch to Windows container mode and build/verify the backend image
2. Screenshot the images list
3. Switch back to Linux mode, restart the frontend container
4. Run the backend natively and demonstrate the working hybrid setup

**Lesson**: Mixed-OS container architectures (Linux + Windows) require switching Docker Desktop's operating system mode, which isolates images of each type. This is a fundamental constraint of Docker Desktop on Windows — there is no way to have both Linux and Windows images visible simultaneously. This reinforces why understanding container OS types and Docker engine configuration is critical when planning containerized deployments.

---

### Summary Table of Problems

| # | Problem | Root Cause | Resolution | Time Spent |
|---|---------|------------|------------|------------|
| 1 | CORS blocked API calls | Browser same-origin policy | Added CORS headers to backend | 15 min |
| 2 | Debug DLL dependencies | Debug CRT not in containers | Release build + static CRT (/MT) | 20 min |
| 3 | Docker Hub timeout | Network/CDN issue | Pull images separately first | 10 min |
| 4 | Windows build mismatch | ltsc2022 incompatible with build 19045 | Switched to ltsc2019 | 15 min |
| 5 | Windows containers disabled | Docker installed without support | Reinstalled Docker Desktop fresh | 30 min |
| 6 | Wine can't see host processes | Fundamental Wine limitation | Abandoned Linux+Wine approach | 45 min |
| 7 | Hyper-V isolation blocks host access | Win10 only supports Hyper-V isolation | Adopted hybrid (backend native) | 30 min |
| 8 | Installer "Missing package flag" | Stub installer needs full package | Fresh download from docker.com | 15 min |
| 9 | Backend image can't build in Linux mode | Docker can only run one OS mode at a time | Clear documentation + two screenshots | 10 min |

**Total troubleshooting time**: ~3 hours 10 min

---

## 9. Lessons Learned

### 9.1 Technical Lessons

1. **Windows API applications cannot be containerized on Windows 10**: System monitoring tools that use Win32 kernel APIs (`EnumProcesses`, `OpenProcess`, `CreateToolhelp32Snapshot`, etc.) require host kernel access. Windows 10 only supports Hyper-V isolation for containers, which provides a separate kernel.

2. **Windows container images are build-specific**: The base image version must match the host Windows version. Always check your build number with `[System.Environment]::OSVersion.Version`.

3. **Static linking eliminates DLL dependencies**: Using `/MT` (MultiThreaded) instead of `/MD` (MultiThreaded DLL) creates self-contained executables that work in any Windows environment without requiring Visual C++ Redistributable.

4. **Wine has fundamental limitations**: Wine translates Windows API calls to Linux equivalents but cannot replicate Windows kernel functionality like process enumeration or system service management.

5. **CORS must be handled server-side**: When a web frontend and API backend run on different ports/services, the backend must include CORS headers. The simplest approach is `Access-Control-Allow-Origin: *`.

6. **Docker Desktop configuration is fixed at install time**: Windows container support is determined during installation and cannot be easily added later. Enable Windows Features first, then install Docker Desktop fresh.

7. **Mixed-OS container architectures have visibility constraints**: Docker Desktop on Windows cannot display Linux and Windows container images at the same time. When planning a hybrid architecture with both Linux and Windows containers, account for this in documentation and presentations — two separate screenshots may be needed.

### 9.2 Project Management Lessons

1. **Test container approaches early**: We spent significant time on Windows container setup that ultimately couldn't work due to Hyper-V isolation limitations. Prototyping the container approach earlier would have revealed this constraint sooner.

2. **Hybrid architectures are valid**: Not every component needs to be containerized. The hybrid approach (backend native, frontend container) demonstrates Docker concepts while respecting the application's architectural constraints.

3. **Document failures alongside successes**: Understanding why certain approaches didn't work is as valuable as knowing what worked. This documentation serves as a reference for future projects with similar constraints.

---

## 10. VMware Integration Concepts

### 10.1 Running on VMware vSphere

The Dockerized application (hybrid architecture) can be deployed on a VMware vSphere infrastructure:

1. **Create a Windows VM on ESXi**: Provision a Windows 10/11 or Windows Server VM with sufficient resources
2. **Install Docker Desktop**: Install on the VM with appropriate container backend
3. **Deploy the project**: Copy project files to the VM
4. **Run**: Start backend natively and frontend via Docker

### 10.2 VMware Architecture

```
VMware vSphere Cluster
│
├── ESXi Host 1
│   └── Windows 10/11 VM (Docker Host)
│       ├── [Native] Backend → Port 8765
│       └── [Docker] Frontend → Port 8080
│
├── ESXi Host 2 (Replica — high availability)
│   └── Windows 10/11 VM (Replica)
│
└── vCenter Server (Centralized Management)
```

### 10.3 VMware Benefits Applied

| VMware Feature | Benefit |
|----------------|---------|
| **vMotion** | Live migration of the Docker host VM without downtime |
| **HA (High Availability)** | Automatic restart of VM on host failure |
| **Snapshots** | Rollback to a known-good state before container updates |
| **DRS** | Automatic load balancing across ESXi hosts |
| **vSphere Storage vMotion** | Migrate container data stores without interruption |
| **Resource Pools** | Allocate guaranteed CPU/memory to the Docker host VM |

---

## 11. Azure Deployment Concepts

### 11.1 Deployment Options

| Azure Service | Use Case | Complexity |
|---------------|----------|------------|
| **Azure Container Registry (ACR)** | Store Docker images privately | Low |
| **Azure Container Instances (ACI)** | Serverless container deployment | Low |
| **Azure Kubernetes Service (AKS)** | Production orchestration and scaling | Medium |
| **Azure Virtual Machines** | Run Docker host on Windows VM | Medium |

### 11.2 Deployment Architecture

```
Azure Cloud
│
├── Azure Container Registry (ACR)
│   ├── taskmgr-backend:v1.0     (Windows container image)
│   └── taskmgr-frontend:v1.0    (Linux container image)
│
├── Azure Container Instances (ACI)
│   ├── taskmgr-backend (Windows container)
│   │   └── Public IP: 20.x.x.x:8765
│   └── taskmgr-frontend (Linux container)
│       └── Public IP: 20.x.x.x:80
│
├── Azure Virtual Network
│   └── VNET with subnets for container communication
│
└── Azure Monitor
    ├── Container logs (Log Analytics)
    └── Performance metrics
```

### 11.3 Deployment Commands

```powershell
# Login
az login

# Create Resource Group
az group create --name TaskManagerRG --location eastus

# Create ACR
az acr create --resource-group TaskManagerRG --name taskmanageracr --sku Basic

# Tag and Push
docker tag taskmgr-frontend:v1.0 taskmanageracr.azurecr.io/taskmgr-frontend:v1.0
docker push taskmanageracr.azurecr.io/taskmgr-frontend:v1.0

# Deploy to ACI
az container create --resource-group TaskManagerRG --name taskmgr-frontend `
  --image taskmanageracr.azurecr.io/taskmgr-frontend:v1.0 `
  --ports 80 --dns-name-label taskmgr-frontend
```

### 11.4 AKS Orchestration (Production)

For production deployment, Azure Kubernetes Service would provide:
- **Auto-scaling**: Scale frontend instances based on CPU/memory
- **Load balancing**: Distribute traffic across multiple frontend instances
- **Rolling updates**: Zero-downtime deployment of new versions
- **Self-healing**: Automatic restart of failed containers
- **Secrets management**: Store API keys and certificates securely

---

## 12. Docker Concepts Demonstrated

| Concept | How Demonstrated |
|---------|-----------------|
| **Dockerfile** | Custom image built for frontend service |
| **Base image selection** | nginx:alpine (minimal, fast) |
| **Multi-service orchestration** | Docker Compose with service definition |
| **Image tagging** | `taskmgr-frontend:v1.0` |
| **Port mapping** | Container 80 → Host 8080 |
| **Dependency management** | depends_on in docker-compose |
| **Build context** | Separate build context per service |
| **Layer caching** | Base images cached for faster rebuilds |
| **Container isolation** | Frontend container isolated from host |
| **Container lifecycle** | Build, tag, run, stop, remove |
| **Windows container types** | Hyper-V isolation vs Process isolation |
| **Multi-architecture awareness** | Linux vs Windows base images |
| **Registry operations** | Docker Hub pull, ACR push (conceptual) |

---

## 13. Final Architecture and Running Instructions

### 13.1 Presentation Quick-Start Guide (From Scratch)

Use this guide to run the complete system during your presentation. Each step includes the exact command and expected output.

---

#### Prerequisites Checklist

Before starting, verify these are installed:

| Software | Check Command | Expected Output |
|----------|--------------|-----------------|
| **Docker Desktop** | `docker --version` | `Docker version 4.x.x` |
| **Docker in Linux mode** | `docker info` (look for OSType) | `OSType: linux` |
| **Backend executable** | `Test-Path "backend\x64\Release\task_manager_backend.exe"` | `True` |
| **Frontend Dockerfile** | `Test-Path "frontend\Dockerfile"` | `True` |

If Docker is in Windows mode, right-click the Docker Desktop tray icon → **Switch to Linux containers**.

---

#### Step 1: Backend — Native Execution

Open **PowerShell** and run:

```powershell
cd "C:\Users\Huzaifa\Desktop\Windows Task Manager\backend\x64\Release"
.\task_manager_backend.exe
```

**Expected output:**
```
GUI Based Task Manager backend starting.
Endpoints:
  /processes  /processes/app  /processes/background  /processes/system
  /details  /sockets  /services  /users  /files
Run with --console to print /processes once and exit.
Backend listening on http://0.0.0.0:8765
```

**Keep this terminal window open.** The backend must stay running.

---

#### Step 2: Frontend — Docker Container

Open a **second** PowerShell window and run:

```powershell
cd "C:\Users\Huzaifa\Desktop\Windows Task Manager"
docker run -d -p 8080:80 --name taskmgr-frontend taskmgr-frontend:v2.0
```

**Expected output:**
```
Unable to find image 'taskmgr-frontend:v2.0' locally   (first time only)
v2.0: Pulling from taskmgr-frontend
... (download progress) ...
Status: Downloaded newer image for taskmgr-frontend:v2.0
<long-container-id>
```

If the image is not found, build it first:
```powershell
docker build -t taskmgr-frontend:v2.0 ./frontend
docker run -d -p 8080:80 --name taskmgr-frontend taskmgr-frontend:v2.0
```

**Verify the container is running:**
```powershell
docker ps
```

**Expected output:**
```
CONTAINER ID   IMAGE                     COMMAND                  CREATED         STATUS         PORTS                  NAMES
abc123def456   taskmgr-frontend:v2.0     "/docker-entrypoint.…"   5 seconds ago   Up 4 seconds   0.0.0.0:8080->80/tcp   taskmgr-frontend
```

---

#### Step 3: Open the Application

Open your web browser and go to:

```
http://localhost:8080
```

**What you should see:**
- Flutter Task Manager UI loads with **6 tabs**: Process, Details, Sockets, Files, Services, Users
- All data is **live** — processes, network connections, services from your actual Windows system
- Your Windows username is displayed correctly (e.g., `DESKTOP-444QJ4I\Huzaifa`)
- Docker Desktop, WhatsApp, VMware, Chrome, VS Code appear under **Apps** tab

---

#### Step 4: Demonstrating Docker Concepts

While the app is running, show these Docker commands:

```powershell
# List running containers
docker ps

# List all images
docker images

# View container logs
docker logs taskmgr-frontend

# Stop the container
docker stop taskmgr-frontend

# Start it again
docker start taskmgr-frontend

# Remove the container (when done)
docker rm taskmgr-frontend
```

---

#### Step 5: Shutting Down

1. Press **Ctrl+C** in the backend terminal to stop the C++ backend
2. Stop and remove the frontend container:
```powershell
docker stop taskmgr-frontend
docker rm taskmgr-frontend
```

---

### 13.2 Quick Reference — All Images and Their Commands

| Image Name | Tag | Build Command | Run Command | Container Type |
|------------|-----|---------------|-------------|----------------|
| `taskmgr-frontend` | `v2.0` | `docker build -t taskmgr-frontend:v2.0 ./frontend` | `docker run -d -p 8080:80 --name taskmgr-frontend taskmgr-frontend:v2.0` | Linux |
| `taskmgr-backend` | `v1.0` | `docker build -t taskmgr-backend:v1.0 ./backend` (Windows mode) | (documentation only — runs natively) | Windows |

### 13.3 If Something Goes Wrong During Presentation

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| `docker: no matching manifest for windows` | Docker in Windows mode | Right-click tray icon → **Switch to Linux containers** |
| `docker: command not found` | Docker Desktop not running | Start Docker Desktop from Start Menu, wait for green status |
| Frontend loads but no data | Backend not running | Start backend exe in a separate terminal |
| "Failed to fetch" in browser | Backend port 8765 not reachable | Check `netstat -ano \| findstr :8765` — backend should be listening |
| Port 8080 already in use | Another app using port 8080 | Change port: `docker run -d -p 8081:80 --name taskmgr-frontend taskmgr-frontend:v2.0`, then visit `localhost:8081` |
| Container exits immediately | Image not built | Run `docker build -t taskmgr-frontend:v2.0 ./frontend` first |

---

### 13.4 Verification Checklist

- [ ] Backend shows `listening on http://0.0.0.0:8765`
- [ ] Frontend container starts without errors
- [ ] `http://localhost:8080` loads the Flutter UI
- [ ] Process tab shows real processes (Chrome, VS Code, explorer, etc.)
- [ ] Username shows your actual Windows username (not ContainerAdministrator)
- [ ] Details tab shows expanded process info
- [ ] Sockets tab shows real network connections
- [ ] Files tab shows file access data
- [ ] Services tab shows Windows services
- [ ] Users tab shows your user account with process grouping

---

## 14. Docker Images and Tags

| Image | Tag | Size | Base | Container Type | Purpose |
|-------|-----|------|------|----------------|---------|
| `taskmgr-backend` | `v1.0` | 5.14 GB | `windows/servercore:ltsc2019` | Windows | Backend API (documentation only) |
| `taskmgr-frontend` | `v1.0` | ~142 MB | `python:3.11-windowsservercore-1809` | Windows | Frontend (first build, Windows) |
| `taskmgr-frontend` | `v2.0` | ~26 MB | `nginx:alpine` | Linux | Frontend (final, lightweight) |
| `nginx` | `alpine` | ~38 MB | `alpine:3.x` | Linux | Base image for frontend |
| `hello-world` | `latest` | ~13 kB | `scratch` | Linux | Test image |
| `alpine` | `latest` | ~7 MB | `scratch` | Linux | Minimal Linux base |

**Note**: The `taskmgr-backend` and `taskmgr-frontend:v1.0` images are Windows containers built in Windows container mode. The frontend's final production image `taskmgr-frontend:v2.0` is a Linux container built with `nginx:alpine`. These images are **not visible simultaneously** — Docker Desktop only shows images matching the current container OS mode (see Problem 9: Backend image cannot be built in Linux container mode).

### Image Build Commands

```powershell
# Build frontend (Linux container mode)
docker build -t taskmgr-frontend:v2.0 ./frontend

# Run frontend container
docker run -d -p 8080:80 --name taskmgr-frontend taskmgr-frontend:v2.0

# Build backend (Windows container mode — requires mode switch)
# Switch Docker to Windows containers, then:
docker build -t taskmgr-backend:v1.0 ./backend

# Pull test images (Linux mode)
docker pull hello-world
docker pull alpine
docker pull nginx:alpine
```

---

## 15. Testing and Verification

### 15.1 Backend API Tests

```powershell
# Test all endpoints
Invoke-RestMethod -Uri http://localhost:8765/processes
Invoke-RestMethod -Uri http://localhost:8765/details
Invoke-RestMethod -Uri http://localhost:8765/sockets
Invoke-RestMethod -Uri http://localhost:8765/services
Invoke-RestMethod -Uri http://localhost:8765/users
Invoke-RestMethod -Uri http://localhost:8765/files
```

### 15.2 Expected API Response Structure

```json
// GET /processes/app
[
  {
    "pid": 1234,
    "name": "chrome.exe (8)",
    "type": "app",
    "cpuPercent": 5,
    "memoryKB": 250000,
    "processCount": 8,
    "allPids": [1234, 5678, ...]
  }
]

// GET /details
[
  {
    "pid": 1234,
    "name": "chrome.exe",
    "type": "app",
    "status": "Running",
    "username": "DESKTOP-444QJ4I\\Huzaifa",
    "cpuPercent": 2,
    "memoryKB": 125000,
    "uacVirtualization": "Disabled"
  }
]
```

### 15.3 Frontend Verification

- Open Browser DevTools (F12) → Network tab
- Navigate through all 6 tabs
- Verify all API calls return HTTP 200
- Verify UI data matches backend responses

---

## 16. Troubleshooting

### Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| Backend won't start | Port 8765 in use | `netstat -ano | findstr :8765` → kill process |
| Frontend shows blank page | Backend not responding | Start backend first, then refresh frontend |
| "Failed to fetch" in UI | CORS not configured | Verify CORS headers in `sendHttpResponse()` |
| Wrong username shown | Container isolation | Run backend natively, not in container |
| Docker build TLS timeout | Network/Docker Hub issue | Pull base images separately first |
| Container exits immediately | Missing DLLs | Compile Release with static CRT (`/MT`) |
| "No matching manifest" | Wrong base image for host | Use `ltsc2019` for Windows 10 builds |

### Useful Diagnostic Commands

```powershell
# Check Windows build
[System.Environment]::OSVersion.Version

# Check Docker mode
docker info | Select-String "OSType"

# Check container logs
docker-compose logs

# Check port usage
netstat -ano | findstr ":8765"

# List all images
docker images

# List running containers
docker ps

# Execute inside container
docker exec -it windowstaskmanager-frontend-1 sh

# Remove all containers/images
docker-compose down --rmi all -v
```

---

## 17. References

### Docker
- [Docker Desktop for Windows](https://docs.docker.com/docker-for-windows/)
- [Docker Compose Reference](https://docs.docker.com/compose/compose-file/)
- [Windows Container Isolation Modes](https://docs.microsoft.com/en-us/virtualization/windowscontainers/deploy-containers/run-containers)
- [Windows Container Base Images](https://hub.docker.com/_/microsoft-windows-servercore)

### Flutter
- [Flutter Web Deployment](https://docs.flutter.dev/deployment/web)
- [Flutter HTTP Package](https://pub.dev/packages/http)

### Azure
- [Azure Container Instances](https://azure.microsoft.com/en-us/products/container-instances/)
- [Azure Container Registry](https://azure.microsoft.com/en-us/products/container-registry/)
- [Azure Kubernetes Service](https://azure.microsoft.com/en-us/products/kubernetes-service/)

### VMware
- [VMware vSphere Documentation](https://docs.vmware.com/en/VMware-vSphere/index.html)
- [VMware vMotion](https://www.vmware.com/products/vsphere/vmotion.html)

### Windows Development
- [Win32 API Documentation](https://docs.microsoft.com/en-us/windows/win32/api/)
- [Visual Studio Downloads](https://visualstudio.microsoft.com/downloads/)
- [Wine Documentation](https://www.winehq.org/documentation)

---

---

## 18. Implementation Summary

The implementation was carried out in the following phases:

### Phase 1: Building the C++ Backend

- Developed the system monitoring engine in C++ using Win32 API calls (EnumProcesses, GetExtendedTcpTable, OpenSCManager, etc.)
- Implemented a custom HTTP server using Winsock2 to expose data via REST API endpoints
- Used bind address `0.0.0.0` (INADDR_ANY) so the backend accepts connections from any network interface (container-ready)
- Added CORS headers (`Access-Control-Allow-Origin: *`, etc.) to HTTP responses for cross-origin browser access
- Added `<RuntimeLibrary>MultiThreaded</RuntimeLibrary>` to the vcxproj for static CRT linking (`/MT`)
- Compiled the backend in **Release x64** mode producing a standalone 360 KB executable (no DLL dependencies)

### Phase 2: Building the Flutter Web Frontend

- Developed the frontend from scratch using Flutter with Material Design 3
- Created 6 tabbed screens: Process, Details, Sockets, Files, Services, Users
- Built data models (Process, SocketConnection, FileAccess, Service, User) to deserialize JSON from the backend
- Implemented ApiService HTTP client for all backend communication
- Compiled to web using `flutter build web --release`
- Output at `frontend/build/web/` — contains `index.html`, `main.dart.js`, assets, and icons

### Phase 3: Dockerfile Creation

**Frontend Dockerfile** (`frontend/Dockerfile`):
- Base image: `nginx:alpine` (~5 MB base) — lightweight, optimized for static file serving
- Copy Flutter web build to nginx's document root (`/usr/share/nginx/html`)
- Expose port 80

**Backend Dockerfile** (`backend/Dockerfile`):
- Base image: `mcr.microsoft.com/windows/servercore:ltsc2019`
- Copy the compiled Release exe
- Expose port 8765
- This image is for documentation — the backend runs natively in the final architecture

### Phase 4: Docker Compose Setup

- Created `docker-compose.yml` defining the frontend service
- Port mapping: Container 80 → Host 8080
- Backend is documented as a native dependency with clear instructions

### Phase 5: Testing and Troubleshooting

Three major containerization approaches were tested and failed before the final hybrid architecture:

1. **Linux + Wine** → Wine cannot see Windows host processes (fundamental Wine limitation)
2. **Windows container + Hyper-V isolation** → Cannot see host processes (Hyper-V kernel isolation)
3. **Windows container + Process isolation** → Not available on Windows 10 (requires Windows Server)

### Phase 6: Final Architecture (Hybrid)

```
[Windows 10 Host]
    ├── Native: task_manager_backend.exe (port 8765)  ← Win32 API access
    └── Docker: nginx:alpine → Flutter Web UI (port 8080)  ← Containerized
```

This architecture was verified with all 6 tabs working, correct username display, and real-time system data.

---

## 19. GUI Overview (Screens and Navigation)

The Flutter Web frontend provides a modern, tabbed interface with 6 main screens. All screens share a consistent layout with a header, tab navigation bar, and content area using Material Design 3 styling.

### 19.1 Common Layout

```
┌─────────────────────────────────────────────────┐
│  🖥  GUI Based Task Manager                      │  ← AppHeader
├────────┬────────┬────────┬────────┬───────┬─────┤
│Process │Details │Sockets │ Files  │Services│Users│  ← Tab Bar
├────────┴────────┴────────┴────────┴───────┴─────┤
│                                                   │
│           [Tab Content Area]                       │  ← Varies per tab
│                                                   │
└─────────────────────────────────────────────────┘
```

The **AppHeader** widget displays the application icon and title. The **Tab Bar** at the top allows switching between all 6 views. Selecting a tab triggers an API call to the backend, and data is displayed in tables, cards, or expandable sections.

### 19.2 Screen-by-Screen Guide

#### Screen 1: Process Tab (Tab 1)

| Aspect | Detail |
|--------|--------|
| **Title** | Processes |
| **Purpose** | Shows all running processes grouped by executable name |
| **Data Source** | `GET /processes` |
| **Layout** | Expandable cards for each app group |
| **Card Header** | App icon + name (e.g., "Chrome (8)") + CPU bar + memory bar |
| **Expanded View** | Individual processes as a table: PID, CPU%, Memory, Status, Actions |
| **Context Menu** | Right-click on a process → "End Task" / "End (Force)" |
| **Error Messages** | "Failed to load processes" if backend is down |
| **Screenshot** | `[Insert screenshot: Processes tab showing grouped apps]` |

#### Screen 2: Details Tab (Tab 2)

| Aspect | Detail |
|--------|--------|
| **Title** | Details |
| **Purpose** | Flat table of all processes with full details |
| **Data Source** | `GET /details` |
| **Layout** | Sortable data table with columns: PID, Name, Type, Status, User, CPU, Memory, UAC |
| **Sorting** | Click any column header to sort ascending/descending |
| **Context Menu** | Right-click → "End Task" / "End (Force)" |
| **Error Messages** | "Failed to load details" — check backend connection |
| **Screenshot** | `[Insert screenshot: Details tab with process table]` |

#### Screen 3: Sockets Tab (Tab 3)

| Aspect | Detail |
|--------|--------|
| **Title** | Sockets |
| **Purpose** | Real-time network connection monitoring |
| **Data Source** | `GET /sockets` |
| **Layout** | Table with columns: Protocol, Local Address, Local Port, Remote Address, Remote Port, State, Process |
| **Security Filtering** | Shows only ESTABLISHED external connections (filters out localhost, loopback) |
| **Context Menu** | Right-click → "End Task" to kill the owning process |
| **Error Messages** | "Failed to load sockets" — backend socket enumeration failed |
| **Notes** | This feature is unique — Windows Task Manager does not show per-connection details |
| **Screenshot** | `[Insert screenshot: Sockets tab with network connections]` |

#### Screen 4: Files Tab (Tab 4)

| Aspect | Detail |
|--------|--------|
| **Title** | Files |
| **Purpose** | Shows files accessed/opened by each process |
| **Data Source** | `GET /files` |
| **Layout** | Expandable sections grouped by process type (Apps, System, Background) |
| **Section Header** | Process name + type badge |
| **Expanded View** | List of file paths with access information |
| **Context Menu** | Right-click → "End Task" |
| **Error Messages** | "Failed to load files" — file enumeration failed |
| **Notes** | Uses multiple methods: NtQueryObject for handles + application-specific path fallbacks |
| **Screenshot** | `[Insert screenshot: Files tab with process file paths]` |

#### Screen 5: Services Tab (Tab 5)

| Aspect | Detail |
|--------|--------|
| **Title** | Services |
| **Purpose** | List all Windows services and manage them |
| **Data Source** | `GET /services` |
| **Layout** | Table with columns: Name, Display Name, Status, Description |
| **Context Menu** | Right-click → "Start Service" (if stopped) / "Stop Service" (if running) |
| **Actions** | Sends `POST /services/{name}/start` or `POST /services/{name}/stop` |
| **Feedback** | Snackbar notification: "Service started successfully" or error message |
| **Error Messages** | "Failed to load services" — SC Manager access failed |
| **Notes** | Faster than navigating services.msc — start/stop directly from the UI |
| **Screenshot** | `[Insert screenshot: Services tab with service list]` |

#### Screen 6: Users Tab (Tab 6)

| Aspect | Detail |
|--------|--------|
| **Title** | Users |
| **Purpose** | Processes grouped by Windows user account |
| **Data Source** | `GET /users` |
| **Layout** | User cards with aggregated resource usage |
| **Card Content** | Username, total processes, total CPU%, total memory, list of process names |
| **Context Menu** | Right-click on a process → "End Task" |
| **Error Messages** | "Failed to load users" — user enumeration failed |
| **Screenshot** | `[Insert screenshot: Users tab with user groups]` |

### 19.3 Common UI Elements

| Element | Behavior |
|---------|----------|
| **AppHeader** | Displays app title and icon at the top of every screen |
| **Tab Bar** | 6 touch-friendly tabs for navigation between screens |
| **Data Tables** | Sortable columns, alternating row colors, scrollable |
| **Expandable Sections** | Click to expand/collapse grouped data (process groups, file sections) |
| **Context Menu** | Right-click on any process row to see available actions |
| **Snackbar** | Temporary notification at the bottom for success/failure of actions |
| **Loading Indicator** | Circular progress indicator while API data is being fetched |
| **Error State** | Centered error message with retry option if API call fails |
| **CPU/Memory Bars** | Visual progress bars showing resource usage percentage |

### 19.4 Possible Errors and Their Handling

| Error | Where It Occurs | User Sees | Cause |
|-------|----------------|-----------|-------|
| Backend unreachable | Any tab | "Failed to load X" + loading spinner | Backend not running or wrong port |
| Empty data | Sockets | "No active connections" | No ESTABLISHED external connections |
| Empty data | Files | "No file data available" | Processes don't have accessible file handles |
| Termination failed | Process/Details | Snackbar: "Failed to terminate process" | Protected process or permission denied |
| Service action failed | Services | Snackbar: "Failed to start/stop service" | Insufficient privileges or service protected |
| Connection refused | Any | Error in console + no data shown | Port 8765 not listening |

### 19.5 Navigation Flow

```
Launch App → http://localhost:8080
                │
                ▼
          AppBar + TabBar
                │
    ┌───────────┼───────────┐
    ▼           ▼           ▼
Processes   Details     Sockets ...
    │           │           │
    ▼           ▼           ▼
 API call → Backend → JSON → UI render

Switching tabs:
  Tap tab → API call loads → Data displayed
  If API fails → Error message shown
  Actions (End Task) → POST request → Snackbar feedback
```

---

## 20. Future Enhancements

The following features and improvements are planned for future versions:

### 20.1 Short-Term (Next Release)

| Enhancement | Description | Technical Approach |
|-------------|-------------|-------------------|
| **Performance tab** | CPU/Memory graphs over time | Collect historical data in backend, serve as time-series JSON |
| **Startup programs tab** | List programs that run at system startup | Query registry: `HKLM\Software\Microsoft\Windows\CurrentVersion\Run` |
| **Auto-refresh toggle** | Enable/disable automatic data refresh | Add a toggle button in the AppBar + setInterval in Flutter |
| **Search/filter bar** | Filter processes by name across all tabs | Add a TextField that sends query param to backend |
| **Dark/Light theme toggle** | Switch between M3 themes | Flutter's ThemeData with dark/light mode toggle |
| **Export data to CSV** | Download process/network data as CSV | Add a download button → backend generates CSV → blob download |

### 20.2 Medium-Term

| Enhancement | Description |
|-------------|-------------|
| **Process tree view** | Show parent-child process relationships using `CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS)` |
| **Resource usage history** | Store CPU/memory history in a ring buffer and graph over 60 seconds |
| **Advanced process info** | Command line arguments, working directory, environment variables |
| **Network bandwidth per process** | Use `GetPerProcessInfo` from IP Helper API |
| **Disk I/O per process** | Query `GetProcessIoCounters` for read/write byte counts |
| **GPU usage per process** | Use `D3DKMTQueryStatistics` or NVIDIA/AMD performance counters |
| **System tray integration** | Minimize to tray with background monitoring |

### 20.3 Long-Term / Architectural

| Enhancement | Description |
|-------------|-------------|
| **Windows Server deployment** | Run backend in process-isolated Windows container on Windows Server 2022 |
| **Azure deployment** | Push images to ACR, deploy via ACI or AKS |
| **Authentication** | Add JWT-based auth for multi-user scenarios |
| **WebSocket real-time updates** | Replace polling with WebSocket push for instant UI updates |
| **REST API versioning** | Add `/api/v1/` prefix for API stability |
| **Unit/integration tests** | Add automated tests for backend (C++) and frontend (Flutter) |
| **CI/CD pipeline** | GitHub Actions to build, test, push images automatically |

---

## 21. Conclusion

This project successfully **built a modern replacement for Microsoft's Windows Task Manager** from scratch — a two-tier system monitoring application with a C++ Win32 backend and a Flutter Web frontend — and then **Dockerized the frontend** for portable deployment. The journey involved understanding deep technical constraints around Windows containerization, particularly the Hyper-V isolation model that prevents containerized applications from accessing host system processes on Windows 10.

### What We Achieved

| Goal | Status | Detail |
|------|--------|--------|
| **Dockerfile for frontend** | ✅ | `nginx:alpine` — serves Flutter Web UI as a static site |
| **Dockerfile for backend** | ✅ | Windows Server Core ltsc2019 — documentation purpose |
| **Docker Compose** | ✅ | Orchestrates frontend service with port mapping |
| **Image tagging** | ✅ | `taskmgr-frontend:v2.0`, `taskmgr-backend:v1.0` |
| **Hybrid architecture** | ✅ | Backend native + frontend containerized |
| **Code modifications** | ✅ | CORS, bind address, static CRT |
| **Additional features** | ✅ | Sockets tab, Files tab, Flutter UI, multi-method termination |
| **Documentation** | ✅ | Full VSS Lab documentation with all 21 sections |

### Key Takeaways

1. **Not every application can be fully containerized** — The backend's dependency on Win32 kernel APIs (EnumProcesses, OpenProcess, etc.) makes it incompatible with container isolation on Windows 10. This is a fundamental constraint, not a limitation of our implementation.

2. **Hybrid architectures are valid and practical** — Running the backend natively while containerizing the frontend demonstrates Docker concepts (Dockerfile, docker-compose, image tagging, port mapping, container lifecycle) while respecting the application's architectural requirements.

3. **Windows containers are different from Linux containers** — Windows containers have isolation mode constraints (Hyper-V vs Process), build-specific base images, and cannot be mixed with Linux containers in the same Docker Desktop instance.

4. **Documentation is as important as code** — Every failed approach, every workaround, and every architectural decision is documented here, making this project a valuable reference for future containerization efforts with similar constraints.

### Final Words

This project was completed in a single day (20th-22nd May 2026) for the Virtual System and Services Lab course. Despite the challenges of limited system resources (4 GB RAM), the complexity of Windows containerization, and the tight deadline, the application is fully functional and demonstrates core Docker, VMware, and Azure concepts as required by the project brief.

---

*Document Version: 3.0*
*Last Updated: May 20, 2026*
*Author: Huzaifa & Danish — VSS Lab Project*
