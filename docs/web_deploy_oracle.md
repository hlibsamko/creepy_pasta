# Web + Oracle deployment

This project now supports a browser client joining a dedicated WebSocket server.

## Local smoke test

Start the server from the project folder:

```bash
godot --headless --path . --server
```

Then run the game normally and join:

```text
ws://127.0.0.1:24567
```

## Oracle VM

1. Create an Always Free VM.
2. Open inbound TCP ports `80`, `443`, and `24567` in the Oracle security rules.
3. Copy the Linux dedicated server export to the VM.
4. Run the server:

```bash
./creepy_pasta_server.x86_64 --headless --server
```

Current test VPS:

```text
ubuntu@138.2.166.64
/home/ubuntu/creepy-pasta-server
TCP 24567
```

The lightweight production path is a native binary plus systemd, not Docker:

```bash
sudo systemctl status creepy-pasta-server
journalctl -u creepy-pasta-server -f
ss -tulpen | grep 24567
```

Oracle-provided Ubuntu images may use iptables even when UFW is not installed. The local VM rule is:

```bash
sudo iptables -I INPUT 5 -p tcp -m state --state NEW -m tcp --dport 24567 -j ACCEPT
sudo netfilter-persistent save
```

Oracle Cloud Console still needs the subnet ingress rule:

```text
Networking -> Virtual cloud networks -> creepy-pasta-vcn
Subnets -> public subnet-creepy-pasta-vcn
Security Lists -> default/security list for the subnet
Add Ingress Rule:
  Source CIDR: 0.0.0.0/0
  IP Protocol: TCP
  Destination Port Range: 24567
  Stateless: No
  Description: Creepy Pasta Godot WebSocket server
```

Keep the existing SSH rule for TCP `22`. Add TCP `80` and `443` only when a domain/reverse proxy is configured for WSS.

For a browser client hosted on HTTPS, use `wss://`. The simplest production setup is Caddy in front of the Godot server:

```caddyfile
creepy-pasta.example.com {
	reverse_proxy 127.0.0.1:24567
}
```

With that proxy, players join:

```text
wss://creepy-pasta.example.com
```

## Godot web export

1. Use the Web export preset.
2. Keep the export single-threaded unless the web host is configured for cross-origin isolation headers.
3. Export the web build as `index.html`.
4. Upload the generated `.html`, `.js`, `.pck`, `.wasm`, and related files to itch.io, Cloudflare Pages, or another static host.

Before exporting for public play, set the `NetworkManager.server_url` value in `scenes/main.tscn` to the production `wss://` address.
