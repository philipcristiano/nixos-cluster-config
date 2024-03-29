# ytdl-sub

Deploys 2 jobs:

* ytdl-sub: Periodic job with Consul-defined subscription
* ytdl-sub-once: Parameterized single download of files

## Consul

`youtube_subscriptions` lists each subscription in the format

`youtube_subscriptions.[SUBSCRIPTION_ID].[OVERRIDE_KEY] = [OVERRIDE_VALUE]`

* `SUBSCRIPTION_ID` is a key to use in YAML for the subscription. It generally won't be visible but is needed for ytdl-sub to track the subscription

* `OVERRIDE_KEY` and `OVERRIDE_VALUE` are the key and value for overrides in the subscription YAML file. Minimal keys are

    * `tv_show_name` - Name of the show / channel / playlist that you want to be visible
    * `url` - The URL of the Youtube channel/playlist
    * `keep_max_files` - Set the number of files to keep. Defaults to not removing any files. Setting to "10" would keep the 10 latest files
