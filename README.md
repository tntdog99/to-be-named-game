## To Be Named Game

Download the latest Windows build (Linux build forthcoming) from GitHub:  
<https://github.com/tntdog99/to-be-named-game/releases>

---

### Prerequisites

- **Windows 10 or later** (Linux support coming soon)  
- **UPnP-enabled router** (required only for public servers)

---

### Installation

1. Download and extract the ZIP archive.  
2. Open the extracted folder.

---

### Usage

#### Game Client

1. Enter the **game-client** directory.  
2. Double-click `game-client.lnk` to launch.

#### Game Host

1. Enter the **game-host** directory.  
2. Double-click `game-server.lnk` to launch.  
3. When prompted, configure:
   - **Server Type**:  
     - `Public` (requires UPnP)  
     - `Private`  
   - **Port Number`

---

### Networking

- **Public Server**  
  - UPnP **must** be enabled on your router.  
  - Clients on the same LAN **cannot** connect via the public IP; use the host’s LAN IP.

- **LAN (Private) Server**  
  - UPnP **not** required.  
  - Clients connect using the host’s LAN IP and specified port.

---

> **Note:**  
> - The Windows release is available now.  
> - The Linux version is pending and will be published here upon release.

_For support or to report issues, please open an issue on the project’s GitHub page._  
