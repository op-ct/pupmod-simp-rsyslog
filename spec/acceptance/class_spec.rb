require 'spec_helper_acceptance'

test_name 'rsyslog class'

describe 'rsyslog class' do
  let(:manifest) {
    <<-EOS
      class { 'rsyslog': }
    EOS
  }

  context 'default parameters' do
    # Using puppet_apply as a helper
    it 'should work with no errors' do
      apply_manifest(manifest, :catch_failures => true)

      # reboot to apply auditd changes
      shell( 'shutdown -r now', { :expect_connection_failure => true } )
    end


    it 'should be idempotent' do
      apply_manifest(manifest, {:catch_changes => true, :acceptable_exit_codes => [0,2]})
    end

    describe package('rsyslog') do
      it { is_expected.to be_installed }
    end

    describe service('rsyslog') do
      it { is_expected.to be_enabled }
      it { is_expected.to be_running }
    end
  end
end
