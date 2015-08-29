require 'beaker-rspec'

# returns an Array of puppet modules declared in .fixtures.yml
def pupmods_in_fixtures_yaml
  require 'yaml'
  fixtures_yml = File.expand_path( '../.fixtures.yml', File.dirname(__FILE__))
  data         = YAML.load_file( fixtures_yml )
  repos        = data.fetch('fixtures').fetch('repositories').keys
  symlinks     = data.fetch('fixtures').fetch('symlinks', {}).keys
  (repos + symlinks)
end

unless ENV['BEAKER_provision'] == 'no'
  hosts.each do |host|
    # Install Puppet
    if host.is_pe?
      install_pe
    else
      install_puppet
    end
  end
end


def spec_prep_if_needed
  unless ENV['BEAKER_spec_prep'] == 'no'
    puts "== checking prepped modules from .fixtures.yml"
    need_prep = 0
    pupmods_in_fixtures_yaml.each do |pupmod|
      mod_root = File.expand_path( "fixtures/modules/#{pupmod}", File.dirname(__FILE__))
      unless File.directory? mod_root
        puts "  ** MISSING module '#{pupmod}' at '#{mod_root}'"
        need_prep += 1
      end
    end

    if need_prep > 0
      puts "  == #{need_prep} modules need to be prepped"
      cmd = 'bundle exec rake spec_prep'
      puts "  -- running spec_prep: '#{cmd}'"
      %x{#{cmd}}
    else
      puts "  == all modules exist; no need to run spec_prep (need_prep = '#{need_prep}'"
    end
  end
end

RSpec.configure do |c|
  # Project root
  proj_root = File.expand_path(File.join(File.dirname(__FILE__), '..'))

  spec_prep_if_needed

  # Readable test descriptions
  c.formatter = :documentation

  # Configure all nodes in nodeset
  c.before :suite do
    # net-tools required for netstat utility being used by be_listening
    if fact('osfamily') == 'RedHat' && fact('operatingsystemmajrelease') == '7'
      pp = <<-EOS
        package { 'net-tools': ensure => installed }
      EOS

      apply_manifest_on(agents, pp, :catch_failures => false)
    end

    # Install module and dependencies
    puppet_module_install(:source => proj_root, :module_name => 'dummy')
    list = [master]
    list.each do |host|
      # allow spec_prep to provide modules (to support isolated networks)
      unless ENV['BEAKER_use_fixtures_dir_for_modules'] == 'no'
        pupmods_in_fixtures_yaml.each do |pupmod|
          mod_root = File.expand_path( "fixtures/modules/#{pupmod}", File.dirname(__FILE__))
          copy_module_to( master, {:source => mod_root, :module_name => pupmod} )
        end
      else
        # TODO: update when the relevant SIMP modules are on the forge
        on host, puppet('module', 'install', 'puppetlabs-stdlib'), { :acceptable_exit_codes => [0,1] }
      end
    end

    # Generate & insert PKI certs into pki/files/keydist on the master
    # FIXME: this path isn't necessarily correct
    pki_dir = File.expand_path( "acceptance/files/pki/", File.dirname(__FILE__))
    on master,  'mkdir -p /root/pki'
    Dir[ File.join(pki_dir, '*' )].each {|f| scp_to( master, f, '/root/pki/')}
    on master,  hosts.map{|x| "echo #{x} >> /root/pki.hosts"  }.join("\n")
    on master,  %q{[ ! -z `hostname -d` ] && sed -i -e "s/$/.`hostname -d`/" /root/pki.hosts}
    on master,  'cd /root/pki; cat /root/pki.hosts | xargs bash make.sh'
    on master,  'rm -rf /etc/puppet/modules/pki/files/keydist/*'
    on master,  'cp -a /root/pki/keydist/ /etc/puppet/modules/pki/files/'
    on master, 'chgrp -R puppet /etc/puppet/modules/pki/files/keydist'
    if ENV['PRY']
      require 'pry'; binding.pry
    end
  end
end
