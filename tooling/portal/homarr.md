# Homarr host portal

A link portal for this machine: one page listing its services, whose links
agents can add, change, and remove through Homarr's API or MCP server. It runs as a Docker Compose project, outside any repository, and is
reachable only on loopback and the machine's private overlay (NetBird) address.

Verified with Homarr `v2.9.1` on Docker Compose v2. Replace each `<PLACEHOLDER>`
below; this repository is public, so never commit real addresses, host names,
keys, or passwords.

| Placeholder | Meaning |
|-------------|---------|
| `<HOMARR_DIR>` | Project directory, e.g. `~/.local/share/homarr` |
| `<OVERLAY_IP>` | This machine's private overlay (NetBird) address |
| `<HOMARR_VERSION>` / `<IMAGE_DIGEST>` | Pinned release and its image digest |
| `<CRED_FILE>` | Secrets file, `~/.config/homarr/credentials.env` |

## Prerequisites

- Docker Engine with the Compose plugin; the setup user is in the `docker` group.
- Port 7575 free (`ss -ltn | grep 7575`).
- The overlay interface is up, so `<OVERLAY_IP>` exists before the container starts.
  If it can come up late, keep `restart: unless-stopped` (Docker retries the bind).

## Install

1. Pick a release and pin its digest. Prefer a pinned tag over `latest`:

   ```bash
   docker pull ghcr.io/homarr-labs/homarr:v<HOMARR_VERSION>
   docker image inspect ghcr.io/homarr-labs/homarr:v<HOMARR_VERSION> \
     --format '{{index .RepoDigests 0}}'
   ```

2. Create the project and the encryption key:

   ```bash
   umask 077
   mkdir -p <HOMARR_DIR>/appdata ~/.config/homarr
   cp tooling/portal/compose.yaml.template <HOMARR_DIR>/compose.yaml   # then fill placeholders
   printf 'SECRET_ENCRYPTION_KEY=%s\n' "$(openssl rand -hex 32)" > <HOMARR_DIR>/.env
   ```

3. Start it and confirm the bind addresses:

   ```bash
   docker compose -f <HOMARR_DIR>/compose.yaml up -d
   ss -ltn | grep 7575      # expect exactly 127.0.0.1 and <OVERLAY_IP>, no 0.0.0.0
   ```

   Do not change firewall, DNS, or overlay settings for this; the bind choice
   is the access control. Binding the overlay address, not `0.0.0.0`, keeps the
   portal off every other interface, including the LAN.

## Bind-address choice

| Option | Result |
|--------|--------|
| `127.0.0.1` + `<OVERLAY_IP>` (used) | Reachable on this machine and from other overlay peers only |
| `0.0.0.0` | Also on the LAN and any public interface; avoid |
| Loopback only | Safest, but unusable from other devices |

## First run

Open `http://<OVERLAY_IP>:7575/` (or the loopback address). The onboarding
wizard asks for an administrator, then a short tour.

1. Generate the admin password and store it before typing it anywhere:

   ```bash
   umask 077
   printf 'HOMARR_ADMIN_USER=admin\nHOMARR_ADMIN_PASSWORD=%s\n' \
     "$(openssl rand -base64 24 | tr -d '/+=')" > <CRED_FILE>
   ```

2. In the wizard, create the administrator with those credentials. Set the
   "usual server address" to the overlay URL and turn analytics off. The Docker
   socket shows as unavailable, which is intended.
3. Finish with "Build my board". Boards are private by default; sign in as the
   admin to see the dashboard.

## Agent identity and API key

Homarr API keys act with the permissions of the user that created them, and
creating a key needs the `admin` permission. So the agent gets its own user in
its own group, and `admin` is granted only for the minute it takes to create the key.

1. **Group** (Manage → Users → Groups → New group, e.g. `agents`). Permissions:
   `app-create`, `app-use-all`, `app-modify-all`, `app-full-all`.
   `app-full-all` is what allows deleting an app; `app-modify-all` alone is refused on delete.
   Do not grant `admin` or `board-modify-all`; board access is per board (step 5).
2. **User** (Manage → Users → New user, e.g. `agent`) with a generated password,
   member of that group. Append it to `<CRED_FILE>` as `HOMARR_AGENT_USER` and `HOMARR_AGENT_PASSWORD`.
3. Temporarily add `admin` to the group, sign in as `agent`, and create a key
   under Manage → Tools → API → Authentication. The key is shown once.
   Append it to `<CRED_FILE>` as `HOMARR_AGENT_API_KEY` (mode 0600), then
   remove `admin` from the group again.
4. **Board access**: as the administrator, open the board's settings
   (`/boards/<BOARD_NAME>/settings`, Access control → Groups), add the `agents` group
   with permission *Modify board*, and save. This lets the key read the board and add,
   move, and remove its items, and nothing more (no rename, visibility, or delete,
   which need *Full access*). Repeat for each board agents should manage.
5. Verify the key is narrow (see below). Never put these values in a repository,
   report, status line, or PR.

The key can read, create, modify, and delete apps, and edit the items on boards
granted in step 4. It cannot manage users, invites, settings, or create boards;
those calls return `403`.

## Agent operation

Source the credentials and call the REST API with the `ApiKey` header
(`<BASE>` is `http://127.0.0.1:7575`):

```bash
. <CRED_FILE>; H="ApiKey: $HOMARR_AGENT_API_KEY"; J='content-type: application/json'
curl -s -H "$H" <BASE>/api/apps                                    # list
curl -s -H "$H" -H "$J" -X POST <BASE>/api/apps -d \
  '{"name":"Svc","description":"","iconUrl":"<ICON_URL>","href":"<LINK>","pingUrl":""}'
curl -s -H "$H" -H "$J" -X PATCH <BASE>/api/apps/<ID> -d '<FULL_APP_BODY>'
curl -s -H "$H" -X DELETE <BASE>/api/apps/<ID>
```

- `pingUrl` is required on create (use `""`), and `PATCH` needs the full body,
  not only the changed field.
- An app in the catalog does not appear on the dashboard until it is an item on a
  board. With board access (see above) the agent places it itself; see "Board items".
- The full machine-readable reference is `<BASE>/api/openapi`.
- MCP clients use the endpoint `<BASE>/api/mcp` with the same header:

  ```json
  { "mcpServers": { "homarr": {
      "url": "<BASE>/api/mcp",
      "headers": { "ApiKey": "<ID>.<TOKEN>" } } } }
  ```

Check scope after any permission change: `GET /api/users`, `GET /api/invites`, and
`POST /api/boards` with the agent key must return `403`, while create, patch, and
delete of a throwaway app, and add, move, and remove of its board item, succeed.

## Board items

`<BOARD_ID>` and the layout ids come from the board read; the REST API has no board
read or item delete, so those use the tRPC and content endpoints below.

```bash
# Read a board: sections, items, layouts (layout role "base" = desktop, "mobile")
curl -s -H "$H" -G <BASE>/api/trpc/board.getBoardByName \
  --data-urlencode 'input={"json":{"name":"<BOARD_NAME>"}}'
# Add an app item (the app must exist; appId must be non-empty)
curl -s -H "$H" -H "$J" -X POST <BASE>/api/boards/items -d \
  '{"boardId":"<BOARD_ID>","kind":"app","options":{"appId":"<APP_ID>"},"size":{"width":2,"height":2}}'
# Move or resize on one layout
curl -s -H "$H" -H "$J" -X PATCH <BASE>/api/boards/<BOARD_ID>/items/<ITEM_ID>/layouts/<LAYOUT_ID> -d \
  '{"xOffset":0,"yOffset":0,"width":2,"height":2}'
# Remove items, create or rename groups: PUT the whole board content
curl -s -H "$H" -H "$J" -X PUT <BASE>/api/boards/<BOARD_ID>/content -d '{"sections":[...],"items":[...]}'
```

- `PUT .../content` replaces everything: read the board first, change the `sections`
  and `items` from that read, and send them back. To remove an item, leave it out;
  deleting an app from the catalog does not remove its board item.
- A group is a `container` section with `options.title` and one `layouts` entry per
  board layout (`layoutId`, offsets, size, `parentSectionId` = the board's `empty`
  section). Items in a group use that section's id as their `sectionId`, with offsets
  relative to the group.
- New items land in the first free spot; PATCH them into place.

## Adding links

Test each URL from this machine first (browser or `curl`), then add it. A service on a
private address needs that address in the link, not `localhost`, so other peers can open it.
A link to a service with a self-signed certificate works but shows a browser warning.
Do not add links to services you have not identified.

## Backup

State is the `appdata` folder (SQLite database) plus `.env`. The encryption key
must travel with the database or stored secrets cannot be decrypted.

```bash
docker compose -f <HOMARR_DIR>/compose.yaml stop
tar -C <HOMARR_DIR> -czf <BACKUP_DIR>/homarr-$(date +%F).tar.gz appdata .env compose.yaml
docker compose -f <HOMARR_DIR>/compose.yaml start
```

Keep the archive private (it holds the encryption key); the credentials file is
not inside it, so back that up separately. Restore by unpacking into an empty
`<HOMARR_DIR>` and running `up -d`.

## Upgrade

Homarr migrates its database on start, so back up first (above).

1. Read the release notes for the target version.
2. Pull the new tag, read its digest, and update the `image:` line.
3. `docker compose -f <HOMARR_DIR>/compose.yaml up -d`, then check the bind
   addresses and that an agent call to `/api/apps` still works.
4. Roll back by restoring the backup and the previous `image:` line; a migrated
   database does not run on an older image.

## Remove

`docker compose -f <HOMARR_DIR>/compose.yaml down` stops it; deleting
`<HOMARR_DIR>/appdata` discards all portal state.
