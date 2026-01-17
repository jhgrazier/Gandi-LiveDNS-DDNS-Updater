# Gandi LiveDNS DDNS Updater (Ruby)

A simple Ruby script that updates one or more **Gandi LiveDNS A records** with your current external IPv4 address.

It reads records from a single `config.txt` file and only updates DNS when the IP actually changes.

This avoids unnecessary API calls and rate limits.

---

## Requirements

- Ruby 2.6 or newer
- `curl` available in PATH
- Domain using **Gandi LiveDNS** nameservers
- Gandi **Personal Access Token (PAT)** with domain technical permissions
- PAT must be scoped to the target domain as a resource

---

## Files

```
gandi-ddns.rb
config.txt
```

---

## Configuration File Format

The script uses an INI-style config file.

### `config.txt`

```
[general]
api = https://api.gandi.net/v5/
api_key = pat_xxxxxxxxxxxxxxxxxxxxxxxxx

[subdomain1.fqdn.com]
domain = fqdn.com
name = subdomain1
type = A
ttl = 300

[subdomain2.fqdn.com]
domain = fqdn.com
name = subdomain2
type = A
ttl = 300
```

---

## How It Works

1. Fetches your external IPv4 address using `https://api.ipify.org`
2. Reads each record from `config.txt`
3. Queries the current DNS record via Gandi LiveDNS
4. Skips the update if the IP has not changed
5. Updates the record with a PUT request if needed
6. Prints the result for each record

---

## Usage

```
ruby gandi-ddns.rb config.txt
```

Example output:

```
subdomain1.fqdn.com: updated to x.x.x.x
subdomain2.fqdn.net: no change (x.x.x.x)
```

---

## Common Errors

### HTTP 403 Forbidden

This means one of the following:

- The PAT does not include the domain as a resource
- The domain is not using Gandi LiveDNS
- The PAT was revoked or is incorrect

Verify DNS hosting:

```
dig +short NS yourdomain.com
```

Verify API access:

```
curl -H "Authorization: Bearer pat_..." \
  https://api.gandi.net/v5/livedns/domains/yourdomain.com
```

---

## Security Notes

- Never commit your PAT to version control
- Revoke any token that was exposed
- Store `config.txt` with permissions `600`

```
chmod 600 config.txt
```

---

## Automation

Example cron job every 5 minutes:

```
*/5 * * * * /usr/bin/ruby /path/to/gandi-ddns.rb /path/to/config.txt >> /var/log/gandi-ddns.log 2>&1
```

---

## Limitations

- IPv4 only
- Supports A records only
- One IP source
- No retries beyond the next cron run

---

## License

MIT License
