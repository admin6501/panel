import subprocess
import os
import re
from typing import Optional, Tuple
from datetime import datetime
import ipaddress


class WireGuardManager:
    def __init__(self, interface: str = "wg0", config_dir: str = "/etc/wireguard"):
        self.interface = interface
        self.config_dir = config_dir
        self.config_file = f"{config_dir}/{interface}.conf"
    
    def generate_keys(self) -> Tuple[str, str]:
        """Generate WireGuard private and public key pair"""
        try:
            private_key = subprocess.run(
                ["wg", "genkey"],
                capture_output=True, text=True, check=True
            ).stdout.strip()
            
            public_key = subprocess.run(
                ["wg", "pubkey"],
                input=private_key,
                capture_output=True, text=True, check=True
            ).stdout.strip()
            
            return private_key, public_key
        except subprocess.CalledProcessError as e:
            raise Exception(f"Failed to generate keys: {e}")
        except FileNotFoundError:
            # WireGuard not installed, return mock keys for development
            import secrets
            import base64
            private = base64.b64encode(secrets.token_bytes(32)).decode()
            public = base64.b64encode(secrets.token_bytes(32)).decode()
            return private, public
    
    def generate_preshared_key(self) -> str:
        """Generate WireGuard preshared key"""
        try:
            psk = subprocess.run(
                ["wg", "genpsk"],
                capture_output=True, text=True, check=True
            ).stdout.strip()
            return psk
        except (subprocess.CalledProcessError, FileNotFoundError):
            import secrets
            import base64
            return base64.b64encode(secrets.token_bytes(32)).decode()
    
    def get_next_ip(self, network: str, used_ips: list[str]) -> str:
        """Get next available IP in the network"""
        net = ipaddress.ip_network(network, strict=False)
        hosts = list(net.hosts())
        
        # Skip first IP (usually server)
        for host in hosts[1:]:
            ip_str = str(host)
            if ip_str not in used_ips:
                return f"{ip_str}/32"
        
        raise Exception("No available IP addresses in the network")
    
    def get_interface_stats(self) -> dict:
        """Get WireGuard interface statistics"""
        try:
            result = subprocess.run(
                ["wg", "show", self.interface, "dump"],
                capture_output=True, text=True
            )
            if result.returncode != 0:
                return {}
            
            stats = {}
            lines = result.stdout.strip().split("\n")
            
            # Skip first line (interface info)
            for line in lines[1:]:
                parts = line.split("\t")
                if len(parts) >= 8:
                    public_key = parts[0]
                    stats[public_key] = {
                        "preshared_key": parts[1] if parts[1] != "(none)" else None,
                        "endpoint": parts[2] if parts[2] != "(none)" else None,
                        "allowed_ips": parts[3],
                        "latest_handshake": int(parts[4]) if parts[4] != "0" else None,
                        "transfer_rx": int(parts[5]),
                        "transfer_tx": int(parts[6]),
                        "persistent_keepalive": parts[7] if parts[7] != "off" else None
                    }
            
            return stats
        except (subprocess.CalledProcessError, FileNotFoundError):
            return {}
    
    def get_client_data_usage(self, public_key: str) -> Tuple[int, int]:
        """Get client data usage (rx, tx) in bytes"""
        stats = self.get_interface_stats()
        if public_key in stats:
            return stats[public_key]["transfer_rx"], stats[public_key]["transfer_tx"]
        return 0, 0
    
    def get_client_last_handshake(self, public_key: str) -> Optional[datetime]:
        """Get client last handshake time"""
        stats = self.get_interface_stats()
        if public_key in stats and stats[public_key]["latest_handshake"]:
            return datetime.fromtimestamp(stats[public_key]["latest_handshake"])
        return None
    
    def add_peer(self, public_key: str, preshared_key: str, allowed_ips: str) -> bool:
        """Add peer to WireGuard interface"""
        try:
            cmd = ["wg", "set", self.interface, "peer", public_key]
            if preshared_key:
                cmd.extend(["preshared-key", "/dev/stdin"])
            cmd.extend(["allowed-ips", allowed_ips])
            
            if preshared_key:
                subprocess.run(cmd, input=preshared_key, text=True, check=True)
            else:
                subprocess.run(cmd, check=True)
            
            self.save_config()
            return True
        except (subprocess.CalledProcessError, FileNotFoundError):
            return False
    
    def remove_peer(self, public_key: str) -> bool:
        """Remove peer from WireGuard interface"""
        try:
            subprocess.run(
                ["wg", "set", self.interface, "peer", public_key, "remove"],
                check=True
            )
            self.save_config()
            return True
        except (subprocess.CalledProcessError, FileNotFoundError):
            return False
    
    def save_config(self) -> bool:
        """Save current WireGuard config to file"""
        try:
            subprocess.run(
                ["wg-quick", "save", self.interface],
                check=True
            )
            return True
        except (subprocess.CalledProcessError, FileNotFoundError):
            return False
    
    def restart_interface(self) -> bool:
        """Restart WireGuard interface"""
        try:
            subprocess.run(["wg-quick", "down", self.interface], check=False)
            subprocess.run(["wg-quick", "up", self.interface], check=True)
            return True
        except (subprocess.CalledProcessError, FileNotFoundError):
            return False
    
    def generate_client_config(
        self,
        client_private_key: str,
        client_address: str,
        server_public_key: str,
        server_endpoint: str,
        preshared_key: str,
        dns: str = "1.1.1.1,8.8.8.8",
        mtu: int = 1420,
        persistent_keepalive: int = 25
    ) -> str:
        """Generate client configuration file content"""
        config = f"""[Interface]
PrivateKey = {client_private_key}
Address = {client_address}
DNS = {dns}
MTU = {mtu}

[Peer]
PublicKey = {server_public_key}
PresharedKey = {preshared_key}
Endpoint = {server_endpoint}
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = {persistent_keepalive}
"""
        return config
    
    def is_wireguard_installed(self) -> bool:
        """Check if WireGuard is installed"""
        try:
            subprocess.run(["wg", "--version"], capture_output=True, check=True)
            return True
        except (subprocess.CalledProcessError, FileNotFoundError):
            return False
    
    def is_interface_up(self) -> bool:
        """Check if WireGuard interface is up"""
        try:
            result = subprocess.run(
                ["wg", "show", self.interface],
                capture_output=True
            )
            return result.returncode == 0
        except FileNotFoundError:
            return False


wg_manager = WireGuardManager()
