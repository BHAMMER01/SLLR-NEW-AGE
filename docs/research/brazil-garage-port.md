# Brazil garage port

The Brazilian installation contains 343 files under `misc/garage`, compared
with 115 files in the New Age validation root. The complete source package is
staged at `assets/official_brazil_garage/garage` so it can be reviewed and
wired into the loader without overwriting the existing garage.

The New Age save schema already preserves `Pneumatic_ShockAbsorber` fields
(`upLength`, `downLength`, `corner`, and damping). The remaining native work is
to expose the garage jack controls, apply the saved ride height to suspension
mounts and render poses, and select the staged garage resources through an
explicit product setting.

No original game files were overwritten in this staging step.
