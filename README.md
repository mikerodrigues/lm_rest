# LMRest

An Unofficial Ruby gem for the LogicMonitor REST API.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'lm_rest'
```

And then execute:

`$ bundle`

Or install it yourself as:

`$ gem install lm_rest`

## Supported API Resources

Every API resource is defined in the `api.json` file and its associated defined
methods are supported. You can easily add your own if you can't wait for me
to update this.

Each method (`get_*, add_*, update_*, delete_*`) works the same
for each resource. Each method name follows the pattern `method_resource`.

Every method except for `delete_*` will return an `LMRest::Resource` object.
It is essentially just a PORO with dynamically created property accessors
(constructed from the API JSON response). This makes it easy to access
attributes, edit them, and update objects. You can get a `Hash` version of the
object with `#to_h`.

Note: This library handles pagination for you! Use `size` and `offset` request
parameters and get sane results. Default `size` is the total number of existing
objects. The default `offset` is 0.

## Usage

See the example `ds_checker.rb` script in `bin` to get a better feel for how to
use the gem.

```ruby
require 'lm_rest'

# Create an instance of the API Client, passing in an API token for 
# authentication. Pretend this portal is at `company.logicmonitor.com`:

lm = LMRest::APIClient.new('company', 'access_id', 'access_key')

# returns array of Resource objects
lm.get_datasources


# get a datasource by id
lm.get_datasource(721)


# return array of Resource objects whose names begin with "VMware"
lm.get_datasources(filter: 'name:VMware*')


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


```

## TODO

* Handle nested stuff, and resource-specific operations


## Contributing

Bug reports and pull requests are welcome.
