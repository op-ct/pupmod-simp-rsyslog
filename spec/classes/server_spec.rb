require 'spec_helper'

describe 'rsyslog::server' do
  shared_examples_for 'a structured module' do
    it { is_expected.to compile.with_all_deps }
    it { is_expected.to contain_class('rsyslog') }
    it { is_expected.to contain_class('rsyslog::server') }
  end

  on_supported_os.each do |os, os_facts|

    context "on #{os}" do
      let(:facts) do
        facts = os_facts.dup
        facts[:selinux_current_mode] = 'disabled'
        facts[:selinux_enforced] = false
        facts
      end

      context 'rsyslog::server class with default parameters and SELinux disabled' do
        let(:params) {{ }}

        it_behaves_like 'a structured module'
        it { is_expected.not_to contain_class('rsyslog::server::firewall') }
        it { is_expected.not_to contain_class('rsyslog::server::tcpwrappers') }
        it { is_expected.not_to contain_class('rsyslog::server::selinux') }
      end

      context 'rsyslog::server class with firewall enabled' do
        let(:params) {{ :enable_firewall => true }}

        it { is_expected.to contain_class('rsyslog::server::firewall') }

        context 'and tls_tcp_server enabled' do
          let(:pre_condition) { 'class{ "rsyslog" : tls_tcp_server => true }' }

          it {
            is_expected.to create_iptables__listen__tcp_stateful('syslog_tls_tcp')
                             .with_dports(6514)
          }

          context 'and tls_tcp_listen_port = 9999' do
            let(:pre_condition) do
              'class{ "rsyslog":
                 tls_tcp_server => true,
                 tls_tcp_listen_port => 9999,
              }'
            end

            it {
              is_expected.to create_iptables__listen__tcp_stateful('syslog_tls_tcp')
                               .with_dports(9999)
            }
          end
        end

        context 'and tcp_server enabled' do
          let(:pre_condition) { 'class{ "rsyslog" : tcp_server => true }' }

          it {
            is_expected.to create_iptables__listen__tcp_stateful('syslog_tcp')
                             .with_dports(514)
          }

          context 'and tcp_listen_port = 9999' do
            let(:pre_condition) do
              'class{ "rsyslog":
                 tcp_server => true,
                 tcp_listen_port => 9999,
              }'
            end
            let(:params) {{ :enable_firewall => true }}
            it {
              is_expected.to create_iptables__listen__tcp_stateful('syslog_tcp')
                               .with_dports(9999)
            }
          end
        end

        context 'and udp_server enabled' do
          let(:pre_condition) { 'class{ "rsyslog" : udp_server => true }' }

          it {
            is_expected.to create_iptables__listen__udp('syslog_udp')
                             .with_dports(514)
          }

          context 'and udp_listen_port = 9999' do
            let(:pre_condition) do
              'class{ "rsyslog":
                 udp_server => true,
                 udp_listen_port => 9999,
              }'
            end

            it {
              is_expected.to create_iptables__listen__udp('syslog_udp')
                               .with_dports(9999)
            }
          end
        end
      end

      context 'rsyslog::server class with SELinux enabled' do
        let(:facts) do
          facts = os_facts.dup
          facts[:selinux_current_mode] = 'enforcing'
          facts[:selinux_enforced] = true
          facts
        end

        it { is_expected.to compile.with_all_deps }
        it_behaves_like 'a structured module'
        it { is_expected.to contain_class('rsyslog::server::selinux') }
        it { is_expected.to create_selboolean('nis_enabled').with({
          :persistent => true,
          :value      => 'on'
        }) }
      end

      context 'with selinux_enforcing fact unset' do
        let(:facts) {os_facts.merge({ :selinux_enforced => nil })}

        it_behaves_like 'a structured module'
        it { is_expected.to contain_class('rsyslog::server') }
        it { is_expected.to_not contain_class('rsyslog::server::selinux') }
      end

      context 'rsyslog::server class with TCPWrappers enabled' do
        let(:params) {{ :enable_tcpwrappers => true }}

        it_behaves_like 'a structured module'
        it { is_expected.to contain_class('rsyslog::server::tcpwrappers') }
      end
    end
  end
end
