# LMRest

An Unofficial Ruby gem for the LogicMonitor REST API.

[![Gem Version](https://badge.fury.io/rb/lm_rest.svg)](https://badge.fury.io/rb/lm_rest)

[LogicMonitor REST API v3 Swagger Docs](https://www.logicmonitor.com/support/rest-api-v3-swagger-documentation)

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'lm_rest'
```

And then execute:

`$ bundle`

Or install it yourself as:

`$ gem install lm_rest`

## Remove system.categories

If you accidentally applied system.categories all over your LogicMonitor
environment, or just need to clean out some old categories, there's an included
demo script just for you.

Install this gem, then check in the `/bin` folder of this repo for the
`system_category_cleaner.rb` script. It's very simple, you'll just need to pass
it the following arguments in order, preferrably in single quotes:
* Your portal name, like `'hooli'`
* Your API access ID like `'long_api_access_id'`
* Your API access Key like `'long_api_access_key'`
* The AppliesTo matching devices you want to scrub like
  `'hascategory("collector")&& system.collectorversion>=24106'`
* The category you want to remove, like `'BadCategory'`

Your devices should be all cleaned up. The script will respect rate limits and
it splits all system.categories on ',' before removing the entry you specify.

It should go without saying that this is unofficial, unsupported, and may mess
your system up even more.


## Supported API Resources

Every API resource and operation is defined in `api.json`, which is generated
from the LogicMonitor REST API v3 Swagger surface. Generated operation methods
and legacy convenience aliases are both supported.

Each method (`get_*, add_*, update_*, delete_*`) works the same for each
resource. Each method name follows the pattern `method_resource`.

Every method except for `delete_*` returns `LMRest::Resource` objects. A
resource is a hash-backed wrapper around the API JSON response with dynamic
attribute-style access, so both `resource.name` and `resource['name']` work.
Use `#to_h` to get a deep-copied `Hash` version suitable for updates.

Paginated GET endpoints are handled automatically. If you omit `size`, the
client will keep requesting pages until all items have been collected. If you
set `size`, the client will fetch up to that many items even when it spans
multiple 1000-item API pages. `offset` defaults to `0`.

## Usage

See the example `ds_checker.rb` script in `bin` to get a better feel for how to
use the gem. It expects:

* LogicMonitor account name
* API access ID
* API access key
* Datasource name or filter glob

```ruby
require 'lm_rest'

# Create an instance of the API Client, passing in an API token for 
# authentication. Pretend this portal is at `company.logicmonitor.com`:

lm = LMRest::APIClient.new('company', 'access_id', 'access_key')

# returns all datasource resources across every API page
lm.get_datasources


# get a datasource by id
lm.get_datasource(721)


# return array of Resource objects whose names begin with "VMware"
# NOTE: when using filter, you need quotes around the filter's "value":
# This is incorrect in the LogicMonitor API docs as of this writing (8/10/2021)
lm.get_datasources(filter: 'name:"VMware*"')


# add a device to your account
lm.add_device({name: 'gibson',
               displayName: 'The Gibson',
               preferredCollectorId: 1,
               hostGroupIds: "1,2",
               description: 'Big iron, heavy metal',
               customProperties: [{name: 'terminal', value: '23'}]})


# add_*, update_*, and delete_* methods accept LMRest::Resource objects:

# get a device by name
device = lm.get_devices({filter: 'name:gibson'})[0]

# change the device's name
device.name = "Gibson"

# update the device with the object
lm.update_device(device)

# delete the device with the object
lm.delete_device(device)

# add the device back
lm.add_device(device)


# Get your Santaba version info
lm.get_version


# ACK Collector Down Alerts!
#
# You can also pass an Alert Resource instead of an id but the comment is
# mandatory!

lm.ack_collector_down(id, comment)


# Run Reports!
lm.run_report(id)


# Handle API failures without leaking response bodies to stdout
begin
  lm.get_device(999999)
rescue LMRest::APIError => e
  warn "#{e.status}: #{e.body}"
end


```

## TODO

* Handle nested stuff, and resource-specific operations


## Contributing

Bug reports and pull requests are welcome.
