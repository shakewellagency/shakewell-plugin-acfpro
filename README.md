# Advanced Custom Fields PRO: Composer mirror

An unmodified copy of the Advanced Custom Fields PRO plugin with a
`composer.json`, so WordPress projects can install it with Composer.

The plugin is written by WP Engine and licensed under the GPL v2 or later.
This repository adds only `composer.json`, this README and the `.github`
folder. It does not include a licence key: the plugin's fields and options
pages work without one, and wp-admin shows a licence notice. Buy a licence at
https://www.advancedcustomfields.com/pro/ for updates and support from the
authors.

## Install

```json
{
    "repositories": [
        {
            "type": "vcs",
            "url": "https://github.com/shakewellagency/shakewell-plugin-acfpro"
        }
    ],
    "require": {
        "shakewellagency/shakewell-plugin-acfpro": "^6.8"
    }
}
```

The plugin installs to `advanced-custom-fields-pro` under your plugin
directory, the same folder name the official zip uses.

## How it is kept up to date

1. `.github/workflows/sync.yml` runs every day. When the upstream mirror
   (`pronamic/advanced-custom-fields-pro`) has a newer release, it copies the
   files onto a `sync/v<version>` branch and opens a pull request.
2. The pull request body holds a comparison of the new files against the
   official free release at the same version
   (`AdvancedCustomFields/acf`). Outside the PRO-only folders, only `acf.php`
   (plugin header), `readme.txt` and two Composer autoload maps should differ.
   Anything else is listed under "Unexpected differences" and must be read
   before merging.
3. A person reviews and merges the pull request.
4. `.github/workflows/tag.yml` then tags the merge commit `v<version>`, which
   is what Composer installs.

Nothing is released without that review. To sync by hand, run the "Sync
upstream" workflow from the Actions tab.
