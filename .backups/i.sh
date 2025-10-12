#!/bin/sh

# ==============================================================================
# ezOS LuCI Application - One-Click Installer v4.5 (Logging Fix)
# This version uses a robust external redirection method to ensure logs are always captured.
# ==============================================================================

# --- Helper Functions ---
log_success() {
    echo "[SUCCESS] $1"
}

log_info() {
    echo "[INFO] $1"
}

log_error() {
    echo "[ERROR] $1" >&2
    exit 1
}

# --- NEW: Aggressive Cleanup Function ---
cleanup_previous_installation() {
    # This part runs silently
    /etc/init.d/ezos stop >/dev/null 2>&1
    /etc/init.d/ezos disable >/dev/null 2>&1
    rm -f /etc/config/ezos
    rm -f /etc/init.d/ezos
    rm -f /usr/bin/ezos_backend.sh
    rm -f /usr/bin/ezos_flash.sh
    rm -f /usr/lib/lua/luci/controller/ezos.lua
    rm -f /usr/lib/lua/luci/controller/ezos_status.lua
    rm -f /usr/lib/lua/luci/model/cbi/ezos.lua
    rm -rf /usr/lib/lua/luci/view/ezos
    rm -f /tmp/luci-indexcache
}

# --- UPDATED: Dependency Check and Install Function ---
check_dependencies() {
    log_info "Checking for required packages..."
    local packages_to_install=""

    check_and_add() {
        local cmd="$1"
        local pkg="$2"
        if ! command -v "$cmd" >/dev/null 2>&1; then
            packages_to_install="$packages_to_install $pkg"
        fi
    }

    check_and_add "gzip" "gzip"
    check_and_add "dd" "coreutils-dd"
    check_and_add "lsblk" "lsblk"
    check_and_add "uci" "uci"

    if [ -n "$packages_to_install" ]; then
        log_info "Attempting to install missing packages: $packages_to_install"
        log_info "Updating opkg package list..."
        opkg update
        if [ $? -ne 0 ]; then
            log_error "Failed to update opkg list. Please check your internet connection."
        fi

        log_info "Installing packages..."
        opkg install $(echo $packages_to_install)
        if [ $? -ne 0 ]; then
            log_error "Failed to install one or more required packages. Please install them manually and try again."
        fi
        log_success "All required packages are now installed."
    else
        log_success "All dependencies are already satisfied."
    fi
}


# --- Main Installation Logic ---
install_package() {
    log_info "Starting ezOS LuCI App installation (v4.5)..."

    # Step 1: Check for root privileges
    if [ "$(id -u)" -ne 0 ]; then
        log_error "This script must be run as root. Please use 'su' or 'sudo'."
    fi

    # Step 2: Clean up previous versions
    cleanup_previous_installation

    # Step 3: Check for and install dependencies
    check_dependencies

    # Step 4: Create necessary directories (silently)
    mkdir -p /usr/bin
    mkdir -p /usr/lib/lua/luci/controller
    mkdir -p /usr/lib/lua/luci/model/cbi
    mkdir -p /usr/lib/lua/luci/view/ezos

    # Step 5: Write all the files using here-documents (silently)

    # --- File: /usr/bin/ezos_flash.sh ---
    cat <<'EOF' > /usr/bin/ezos_flash.sh
#!/bin/sh
# This script's output (stdout & stderr) is intended to be redirected by the caller.

LOCK_FILE="/tmp/peditx.lock"
IMG_GZ_PATH="$1"
TARGET_DISK="$2"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - [ezOS Flasher] - $1"
}

# The trap's output will also be redirected by the caller.
trap 'rm -f "$LOCK_FILE"; log "Flash script finished."' EXIT TERM INT

# --- Lock File Check ---
if [ -f "$LOCK_FILE" ]; then
    log "ERROR: Another PeDitXOS process is running. Please wait for it to finish."
    exit 1
fi
touch "$LOCK_FILE"

# --- Sanity Checks ---
if [ -z "$IMG_GZ_PATH" ] || [ ! -f "$IMG_GZ_PATH" ]; then
    log "ERROR: Image file not provided or not found."
    exit 1
fi
if [ -z "$TARGET_DISK" ] || [ ! -b "$TARGET_DISK" ]; then
    log "ERROR: Target disk not provided or it is not a block device."
    exit 1
fi

# --- Flashing Process ---
log "Starting flash process..."
log "Source Image: $IMG_GZ_PATH"
log "Target Disk: $TARGET_DISK"
log "This will take several minutes. Do NOT close the browser window."
log "-------------------------------------------------------------"

# The output of this pipeline (stderr from dd) will be caught by the caller's redirection.
gzip -d -c "$IMG_GZ_PATH" | dd of="$TARGET_DISK" bs=4M conv=fsync status=progress

DD_STATUS=${PIPESTATUS[1]}

if [ "$DD_STATUS" -eq 0 ]; then
    log "-------------------------------------------------------------"
    log "SUCCESS: Flashing completed."
    sync
    log "Disk synced. It is now safe to reboot."
else
    log "-------------------------------------------------------------"
    log "ERROR: dd command failed with status code $DD_STATUS."
    log "Flashing process failed. Please check the log for details."
fi

rm -f "$IMG_GZ_PATH"
log "Cleaned up temporary image file."
EOF
    chmod +x /usr/bin/ezos_flash.sh

    # --- File: /usr/lib/lua/luci/controller/ezos.lua ---
    cat <<'EOF' > /usr/lib/lua/luci/controller/ezos.lua
module("luci.controller.ezos", package.seeall)

local i18n = require "luci.i18n"

function index()
    local sys = require "luci.sys" 
    
    if luci.http.formvalue("flash_image_action") then
        local image_file = luci.http.formfile("image")
        local target_disk = luci.http.formvalue("disk")

        if image_file and image_file.tmpfile and target_disk then
            local tmp_path = "/tmp/ezos_upload.img.gz"
            sys.exec("mv %s %s" % {image_file.tmpfile, tmp_path})
            
            -- This command now wraps the script call and handles all output redirection externally.
            local cmd = string.format("( /usr/bin/ezos_flash.sh '%s' '%s' ) >> /tmp/peditxos_log.txt 2>&1 &", tmp_path, target_disk)
            sys.exec(cmd)
        end
        
        luci.http.redirect(luci.dispatcher.build_url("admin", "peditxos", "ezos"))
        return
    end

    -- Call the CBI model directly for maximum stability
    entry({"admin", "peditxos", "ezos"}, cbi("ezos"), i18n.translate("ezOS Manager"), 90).dependent = true
    -- AJAX endpoint for the log
    entry({"admin", "peditxos", "ezos", "flash_log"}, call("get_flash_log")).leaf = true
end

function get_flash_log()
    luci.http.prepare_content("application/json")
    local log_file = "/tmp/peditxos_log.txt"
    -- Use robust io.open to read the file content
    local f = io.open(log_file, "r")
    local log_content
    if f then
        log_content = f:read("*a")
        f:close()
    end

    if not log_content or log_content == "" then
        log_content = "Welcome to ezOS Flasher. The log will appear here once you start the process."
    end
    luci.http.write_json({ log = log_content })
end
EOF

    # --- File: /usr/lib/lua/luci/model/cbi/ezos.lua ---
    cat <<'EOF' > /usr/lib/lua/luci/model/cbi/ezos.lua
local i18n = require "luci.i18n"

-- The main map with the page title
m = Map("ezos", i18n.translate("ezOS Manager"))

-- A special section to inject our custom styles and container
s_style = m:section(SimpleSection, "")
s_style.anonymous = true
s_style.template = "ezos/style"

-- The flasher section
s_flasher = m:section(SimpleSection, i18n.translate("Image Flasher"),
    i18n.translate("Upload a compressed OpenWrt image (.img.gz) and flash it to a disk."))
s_flasher.anonymous = true
s_flasher.template = "ezos/flasher"

-- The progress section
s_progress = m:section(SimpleSection, i18n.translate("Flashing Progress"))
s_progress.anonymous = true
s_progress.template = "ezos/flash_status"

return m
EOF

    # --- File: /usr/lib/lua/luci/view/ezos/style.htm (Button Color Fix) ---
    cat <<'EOF' > /usr/lib/lua/luci/view/ezos/style.htm
<style>
    /* ===== UNIFIED THEME (Dracula Inspired) - Integrated from PeDitXOS Tools ===== */
    :root {
        --bg-color: #282a36;
        --card-bg: #3a3c51;
        --header-bg: #21222c;
        --text-color: #f8f8f2;
        --primary-color: #50fa7b;
        --secondary-color: #ff79c6;
        --danger-color: #ff5555;
        --border-color: #44475a;
        --hover-color: #44475a;
    }

    /* Style the main CBI form container */
    .cbi-map {
        max-width: 900px;
        margin: 20px auto !important;
        padding: 25px !important;
        background-color: var(--card-bg) !important;
        border: 1px solid var(--border-color) !important;
        border-radius: 8px;
        box-shadow: 0 4px 12px rgba(0,0,0,0.2);
        color: var(--text-color);
    }

    /* Style titles and descriptions */
    .cbi-map-title h2, .cbi-section-title h3, .cbi-section-descr {
        color: var(--text-color) !important;
    }
    .cbi-map-title h2 {
        font-size: 24px;
        font-weight: 600;
        border-bottom: none;
        padding-bottom: 0;
        margin-bottom: 25px;
    }
    .cbi-section-title h3 {
        border-bottom: 2px solid var(--border-color);
        padding-bottom: 10px;
        margin-top: 20px;
    }
    .cbi-section {
        background: none !important;
        box-shadow: none !important;
        border: none !important;
        padding: 0 !important;
    }

    /* Style form elements */
    .cbi-value-title {
        color: var(--text-color) !important;
    }
    input[type="file"], .cbi-input-select {
        background-color: var(--bg-color) !important;
        border: 1px solid var(--border-color) !important;
        color: var(--text-color) !important;
        padding: 10px;
        border-radius: 5px;
        width: 100%;
        box-sizing: border-box;
    }
    
    /* Style file input button */
    input[type="file"]::file-selector-button {
        background-color: var(--danger-color); /* Red button for visibility */
        color: var(--text-color);
        border: none;
        padding: 8px 12px;
        border-radius: 4px;
        margin-right: 10px;
        cursor: pointer;
        transition: background-color 0.2s;
    }

    input[type="file"]::file-selector-button:hover {
        background-color: #ff6e6e; /* Lighter red on hover */
    }

    /* Remove the default Save & Apply buttons */
    .cbi-page-actions {
        display: none;
    }
    
    /* Pulse Animation */
    @keyframes pulse {
        0% { transform: scale(1); box-shadow: 0 0 0 0 rgba(255, 174, 66, 0.7); }
        70% { transform: scale(1.02); box-shadow: 0 0 0 10px rgba(255, 174, 66, 0); }
        100% { transform: scale(1); }
    }

    /* Custom Flash Button Style */
    .ezos-flash-button {
        font-size: 16px;
        padding: 10px 30px;
        font-weight: bold;
        border: none;
        border-radius: 50px;
        box-shadow: 0 4px 15px rgba(0,0,0,0.2);
        transition: background 0.3s ease, transform 0.2s ease;
        cursor: pointer;
        background: linear-gradient(135deg, #ffae42, #ff8c00); /* Orange gradient from your theme */
        color: #21222c; /* Dark text for contrast */
        text-shadow: 0 1px 1px rgba(0,0,0,0.2);
        animation: pulse 2.5s infinite;
    }

    .ezos-flash-button:hover {
        background: linear-gradient(135deg, #ff8c00, #e87a00);
        transform: translateY(-2px);
        animation-play-state: paused;
    }

    /* Responsive layout for smaller screens */
    @media (max-width: 768px) {
        .cbi-value-title {
            width: auto !important; /* Let the label take its natural width */
            float: none !important;
            text-align: left;
            padding: 0 0 8px 0 !important; /* Give some space below the label */
        }
        .cbi-value-field {
            margin-left: 0 !important;
            width: 100%;
        }
    }
</style>
EOF

    # --- File: /usr/lib/lua/luci/view/ezos/flasher.htm ---
    cat <<'EOF' > /usr/lib/lua/luci/view/ezos/flasher.htm
<div class="cbi-section">
	<form method="post" action="<%=REQUEST_URI%>" enctype="multipart/form-data">
		<div class="cbi-value" style="margin-bottom: 20px;">
			<label class="cbi-value-title" for="image"><%:Upload Image%></label>
			<div class="cbi-value-field">
				<input type="file" name="image" id="image" accept=".gz" required="required" />
			</div>
		</div>

		<div class="cbi-value">
			<label class="cbi-value-title" for="disk"><%:Target Disk%></label>
			<div class="cbi-value-field">
				<select name="disk" id="disk" class="cbi-input-select" required="required">
					<option value="" disabled selected><%:Select a disk...%></option>
					<%
						local f = io.popen("lsblk -d -n -o NAME,SIZE | grep -E 'sd|vd|nvme|mmcblk'")
						if f then
							for line in f:lines() do
								local disk, size = line:match("^(%S+)%s+(%S+)")
								if disk and size then
									write(string.format('<option value="/dev/%s">/dev/%s (%s)</option>', disk, disk, size))
								end
							end
							f:close()
						end
					%>
				</select>
			</div>
		</div>
		
		<div style="text-align: center; padding-top: 30px;">
			<input type="hidden" name="flash_image_action" value="1" />
			<input type="submit" class="ezos-flash-button" value="<%:Flash Image%>" onclick="return confirm('<%:WARNING: All data on the selected disk will be PERMANENTLY ERASED. Are you absolutely sure?%>')" />
		</div>
	</form>
</div>
EOF

    # --- File: /usr/lib/lua/luci/view/ezos/flash_status.htm ---
    cat <<'EOF' > /usr/lib/lua/luci/view/ezos/flash_status.htm
<!-- The outer wrappers are removed to allow the <pre> tag to take full width -->
<pre id="flash_log_content" style="width: 100%; box-sizing: border-box; min-height: 200px; max-height: 400px; margin-top: 15px; overflow-y: scroll; background-color: #282a36; color: #f8f8f2; border: 1px solid #44475a; padding: 15px; border-radius: 5px; font-family: monospace; white-space: pre-wrap; word-wrap: break-word;"><%:Loading log...%></pre>

<script type="text/javascript">//<![CDATA[
	var logElement = document.getElementById('flash_log_content');
	XHR.poll(2, '<%=luci.dispatcher.build_url("admin", "peditxos", "ezos", "flash_log")%>', null,
		function(x, data) {
			if (logElement && data && data.log != null) {
				if (logElement.textContent !== data.log) {
					logElement.textContent = data.log;
					logElement.scrollTop = logElement.scrollHeight;
				}
			}
		}
	);
//]]></script>
EOF

    # --- Step 6: Finalize installation ---
    
    # --- Pre-create the log file to prevent read errors ---
    touch /tmp/peditxos_log.txt
    
    # --- Configure firewall to allow LuCI access from WAN ---
    uci -q delete firewall.luci_wan # Delete old rule to avoid duplicates
    uci set firewall.luci_wan=rule
    uci set firewall.luci_wan.name='Allow-LuCI-WAN'
    uci set firewall.luci_wan.src='wan'
    uci set firewall.luci_wan.dest_port='80 443'
    uci set firewall.luci_wan.proto='tcp'
    uci set firewall.luci_wan.target='ACCEPT'
    uci commit firewall
    /etc/init.d/firewall restart > /dev/null 2>&1
    
    log_success "Installation complete!"
    log_info "Please log out and log back into LuCI to see the new 'ezOS Manager' under the 'PeDitXOS Tools' menu."
}

# --- Script Entry Point ---
install_package

