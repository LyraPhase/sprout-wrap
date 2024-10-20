# -*- mode: ruby -*-
# vi: set ft=ruby :
require 'yaml'
require 'uri'
require 'net/http'

Vagrant.configure("2") do |config|
  # All Vagrant configuration is done here. The most common configuration
  # options are documented and commented below. For a complete reference,
  # please see the online documentation at vagrantup.com.

  # Every Vagrant virtual environment requires a box to build off of.
  config.vm.box = "OSX-10.8.4-Mountain_Lion-x64"

  # The url from where the 'config.vm.box' box will be fetched if it
  # doesn't already exist on the user's system.
  local_box = "#{ENV['HOME']}/src/pub/veewee/OSX-10.8.4-Mountain_Lion-x64.box"
  if File.exists? local_box
    url = local_box
  else
    url = 'http://bro-fs-01.bro.gloostate.com/boxes/OSX-10.8.4-Mountain_Lion-x64.box'
    # Check if bro-fs-01 is accessible, else use aws mirror
    uri = URI(url)
    request = Net::HTTP.new uri.host
    begin
      response = request.request_head uri.path
      raise response.code_type.to_s unless response.code.to_i == 200
    rescue
      url = 'https://s3.amazonaws.com/gloo.development/OSX-10.8.4-Mountain_Lion-x64.box';
    end
  end
  puts "Using Vagrant box from: #{url}"

  config.vm.box_url = url

  # Create a forwarded port mapping which allows access to a specific port
  # within the machine from a port on the host machine. In the example below,
  # accessing "localhost:8080" will access port 80 on the guest machine.
  # config.vm.network :forwarded_port, guest: 80, host: 8080

  # Create a private network, which allows host-only access to the machine
  # using a specific IP.
  # config.vm.network :private_network, ip: "192.168.33.10"

  # Create a public network, which generally matched to bridged network.
  # Bridged networks make the machine appear as another physical device on
  # your network.
  # config.vm.network :public_network

  # Share an additional folder to the guest VM. The first argument is
  # the path on the host to the actual folder. The second argument is
  # the path on the guest to mount the folder. And the optional third
  # argument is a set of non-required options.
  # config.vm.synced_folder "../data", "/vagrant_data"

  # Provider-specific configuration so you can fine-tune various
  # backing providers for Vagrant. These expose provider-specific options.
  # Example for VirtualBox:
  #
  # config.vm.provider :virtualbox do |vb|
  #   # Don't boot with headless mode
  #   vb.gui = true
  #
  #   # Use VBoxManage to customize the VM. For example to change memory:
  #   vb.customize ["modifyvm", :id, "--memory", "1024"]
  # end
  #
  # View the documentation for the provider you're using for more
  # information on available options.

  # Enable provisioning with chef solo, specifying a cookbooks path, roles
  # path, and data_bags path (all relative to this Vagrantfile), and adding
  # some recipes and/or roles.
  #
  config.vm.provision :chef_solo do |chef|
    chef.roles_path = "./roles"
    chef.cookbooks_path = [ 'cookbooks', 'site-cookbooks' ]
    chef.data_bags_path    = './data_bags'
    chef.encrypted_data_bag_secret_key_path = "#{ENV['HOME']}/.chef/encrypted_data_bag_secret"

    # Set chef provisioner log level [ :debug, :info, :warn, :error, :fatal ]
    chef.log_level = :debug

    soloistrc = YAML.load(File.open('soloistrc', 'r'))

    soloistrc['recipes'].each do |recipe|
      chef.add_recipe recipe
    end

    # chef.add_recipe "mysql"
    # chef.add_role "web"

    # You may also specify custom JSON attributes:
    # chef.json = { :mysql_password => "foo" }
  end

  # Enable provisioning with chef server, specifying the chef server URL,
  # and the path to the validation key (relative to this Vagrantfile).
  #
  # The Opscode Platform uses HTTPS. Substitute your organization for
  # ORGNAME in the URL and validation key.
  #
  # If you have your own Chef Server, use the appropriate URL, which may be
  # HTTP instead of HTTPS depending on your configuration. Also change the
  # validation key to validation.pem.
  #
  # config.vm.provision :chef_client do |chef|
  #   chef.chef_server_url = "https://api.opscode.com/organizations/ORGNAME"
  #   chef.validation_key_path = "ORGNAME-validator.pem"
  # end
  #
  # If you're using the Opscode platform, your validator client is
  # ORGNAME-validator, replacing ORGNAME with your organization name.
  #
  # If you have your own Chef Server, the default validation client name is
  # chef-validator, unless you changed the configuration.
  #
  #   chef.validation_client_name = "ORGNAME-validator"
end
