# Troubleshooting

## Cloud-Init snippet upload fails

Example:

```
failed to open SSH client
unable to authenticate user
```

Cause:

The Proxmox provider uploads Cloud-Init snippets over SSH.

Verify:

```bash
echo $SSH_AUTH_SOCK
```

Verify loaded identities:

```bash
ssh-add -L
```

If empty:

```bash
ssh-add ~/.ssh/id_ed25519
```

---

## Verify SSH

```bash
ssh root@<proxmox-host>
```

---

## Verify Proxmox API

```bash
curl \
-H "Authorization: PVEAPIToken=..." \
https://<host>:8006/api2/json/version
```