# waybar-power-consumption



<img width="183" height="32" alt="image" src="https://github.com/user-attachments/assets/ddb5091b-42cb-4eb0-ad93-1fe5d0573d89" /> <img width="187" height="32" alt="image" src="https://github.com/user-attachments/assets/d67e4a76-3779-4516-add6-858e63cc4681" /> <img width="184" height="29" alt="image" src="https://github.com/user-attachments/assets/da098d20-d825-4795-ba6f-8786da335edf" />


A tiny, dependency-light script that reports total system power draw (watts) in a JSON format suitable for waybar's `custom/script` module.

- Script: `power.sh` — reads power from ACPI battery or CPU RAPL and prints JSON for waybar.
- Helpful helper: `install.sh` — optional helper that installs a systemd oneshot service to fix permissions for RAPL energy reporting on some systems.


## Quick summary
- Laptops: prefers values from `/sys/class/power_supply/BAT*/power_now` (or voltage/current fallback).
- Desktops/AC: uses Intel RAPL energy counter at `/sys/class/powercap/intel-rapl:0/energy_uj` and measures difference over 1 second.
- Output: prints a one-line JSON object with `text` and `tooltip` fields — ready for waybar.

## Requirements
- bash
- `bc` (for floating-point calculations)
- Read access to the relevant sysfs paths:
  - `/sys/class/power_supply/*` for battery-based measurements
  - or `/sys/class/powercap/intel-rapl:0/energy_uj` for RAPL-based measurements


# Install / use

1. Clone this repo

2. Run install.sh using root/sudo

3. Add a waybar module that executes the script periodically. Example waybar config snippet:

```
{
  "modules-left": ["custom/power"],
  "custom/power": {
    "exec": "location/of/script/power.sh",
    "interval": 10,
    "return-type": "json",
    "format": "{text}"
  }
}
```

4. Use inside a module

```
"modules-center": [
  ...
  "custom/power"
  ...
]
```

5. Update style.css

```
/* Allow JSON color to apply as default */
#custom-power { color: inherit; }

/* Optional: explicitly assign colors based on class emitted by script */
#custom-power.normal { color: #A8E6CF; }    /* ok (pastel green) */
#custom-power.warning { color: #F6E27F; }   /* pastel yellow */
#custom-power.critical { color: #FF9B9B; }  /* pastel red */
#custom-power.unknown { color: #9E9E9E; }   /* grey */
```

- `interval`: update frequency in seconds (10 is a reasonable start).
- `return-type: "json"` tells waybar to parse the JSON the script prints.

## Systemd permission fix for RAPL (optional)
- On some systems the RAPL energy file is not world-readable by default. The repo includes `install.sh` to create and enable a systemd oneshot service that fixes the permission on boot.
