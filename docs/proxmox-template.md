# Ubuntu Template

The Ubuntu template is created manually.

The template only contains:

- Ubuntu Server
- cloud-init
- qemu-guest-agent

Everything else is configured by Cloud-Init.

## Required packages

```bash
sudo apt update

sudo apt install \
    cloud-init \
    qemu-guest-agent
```

Enable QEMU Guest Agent:

```bash
sudo systemctl enable qemu-guest-agent
sudo systemctl start qemu-guest-agent
```

Clean Cloud-Init before converting to template:

```bash
sudo cloud-init clean
sudo truncate -s 0 /etc/machine-id
sudo poweroff
```