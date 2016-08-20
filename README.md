# LMRest


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

Every API resource defined in the `api.json` file and its associated defined
methods are supported, and you can easily add your own if you can't wait for me
to update this.

Each method (`get_*, add_*, update_*, delete_*`) works the same
for each resource. Each method name follows the pattern `method_resource`.

Every method except for `delete_*` will return an `LMRest::Resource` object.
It is essentially just a PORO with dynamically created property accessors
(constructed from the API JSON response). This makes it easy to access
attributes, edit them, and update objects. You can get a `Hash` version of the
object with `#to_h`.

## Usage

See the example `ds_checker.rb` script in `bin` to get a better feel for how to
use the gem.

```ruby
require 'lm_rest'

lm = LMRest.new(company_name, user_id, password)


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
```


## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).


## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/mikerodrigues/lm_rest.
