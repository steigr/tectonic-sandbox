def signTLS(is_ca:, subject:, issuer_subject:'', issuer_cert:nil, public_key:, ca_private_key:, key_usage:'', extended_key_usage:'', san:'')
  cert = OpenSSL::X509::Certificate.new
  cert.subject = OpenSSL::X509::Name.parse(subject)
  if (is_ca)
    cert.issuer = OpenSSL::X509::Name.parse(subject)
  else
    cert.issuer = OpenSSL::X509::Name.parse(issuer_subject)
  end
  cert.not_before = Time.now
  cert.not_after = Time.now + 365 * 24 * 60 * 60
  cert.public_key = public_key
  cert.serial = Random.rand(1..65534)
  cert.version = 2

  ef = OpenSSL::X509::ExtensionFactory.new
  ef.subject_certificate = cert
  if (is_ca)
    ef.issuer_certificate = cert
  else
    ef.issuer_certificate = issuer_cert
  end
  if (is_ca)
    cert.extensions = [
      ef.create_extension("keyUsage", "digitalSignature,keyEncipherment,keyCertSign", true),
      ef.create_extension("basicConstraints","CA:TRUE", true),
      ef.create_extension("subjectKeyIdentifier", "hash"),
  ]
  else
    # The ordering of these statements is done the way it is to match the way terraform does it
    cert.extensions = []
    if (key_usage != "")
      cert.extensions += [ef.create_extension("keyUsage", key_usage, true)]
    end
    if (extended_key_usage != "")
      cert.extensions += [ef.create_extension("extendedKeyUsage", extended_key_usage, true)]
    end
    cert.extensions += [ef.create_extension("basicConstraints","CA:FALSE", true)]
    cert.extensions += [ef.create_extension("authorityKeyIdentifier", "keyid,issuer")]
    if (san != "")
      cert.extensions += [ef.create_extension("subjectAltName", san, false)]
    end
  end

  cert.sign ca_private_key, OpenSSL::Digest::SHA256.new
  return cert
end

def provision config, node_config, node_provider

  File.write(node_config + ".ign",`ct -pretty -platform #{node_provider == "virtualbox" ? "vagrant-virtualbox" : "custom"} < #{node_config}.clc`)


  if !File.directory?("provisioning/etc")
    require 'openssl'
    require 'base64'

    FileUtils::mkdir_p 'provisioning/etc/ssl/etcd'
    FileUtils::mkdir_p 'provisioning/etc/kubernetes'
    FileUtils::mkdir_p 'provisioning/tectonic/auth'
    FileUtils::mkdir_p 'provisioning/tectonic/tls'
    FileUtils::mkdir_p 'provisioning/tectonic/tls/etcd'

    # BEGIN ETCD CA
    etcd_key = OpenSSL::PKey::RSA.new(2048)
    etcd_public_key = etcd_key.public_key

    etcd_cert = signTLS(is_ca:          true,
                        subject:        "/C=/ST=/L=/postalCode=/O=etcd/OU=/CN=etcd-ca",
                        public_key:     etcd_public_key,
                        ca_private_key: etcd_key,
                        key_usage:      "digitalSignature,keyEncipherment,keyCertSign")

    etcd_file = File.new("provisioning/etc/ssl/etcd/ca.crt", "wb")
    etcd_file.syswrite(etcd_cert.to_pem)
    etcd_file.close
    etcd_file_tec = File.new("provisioning/tectonic/tls/etcd-client-ca.crt", "wb")
    etcd_file_tec.syswrite(etcd_cert.to_pem)
    etcd_file_tec.close
    # END ETCD CA

    # BEGIN ETCD SERVER
    server_key = OpenSSL::PKey::RSA.new(2048)
    server_public_key = server_key.public_key

    server_cert = signTLS(is_ca:              false,
                          subject:            "/C=/ST=/L=/postalCode=/O=etcd/OU=/CN=etcd",
                          issuer_subject:     "/C=/ST=/L=/postalCode=/O=etcd/OU=/CN=etcd-ca",
                          issuer_cert:        etcd_cert,
                          public_key:         server_public_key,
                          ca_private_key:     etcd_key,
                          key_usage:          "keyEncipherment",
                          extended_key_usage: "serverAuth",
                          san:                "DNS:localhost,DNS:*.kube-etcd.kube-system.svc.cluster.local,DNS:kube-etcd-client.kube-system.svc.cluster.local,DNS:kubernetes.sandbox,IP:127.0.0.1,IP:172.17.4.101,IP:10.3.0.15,IP:10.3.0.20")

    server_file = File.new("provisioning/etc/ssl/etcd/server.crt", "wb")
    server_file.syswrite(server_cert.to_pem)
    server_file.close
    server_file_tec = File.new("provisioning/tectonic/tls/etcd/server.crt", "wb")
    server_file_tec.syswrite(server_cert.to_pem)
    server_file_tec.close

    server_key_file= File.new("provisioning/etc/ssl/etcd/server.key", "wb")
    server_key_file.syswrite(server_key.to_pem)
    server_key_file.close
    server_key_tec = File.new("provisioning/tectonic/tls/etcd/server.key", "wb")
    server_key_tec.syswrite(server_key.to_pem)
    server_key_tec.close
    # END ETCD SERVER

    # BEGIN ETCD PEER
    peer_key = OpenSSL::PKey::RSA.new(2048)
    peer_public_key = peer_key.public_key

    peer_cert = signTLS(is_ca:              false,
                        subject:            "/C=/ST=/L=/postalCode=/O=etcd/OU=/CN=etcd",
                        issuer_subject:     "/C=/ST=/L=/postalCode=/O=etcd/OU=/CN=etcd-ca",
                        issuer_cert:        etcd_cert,
                        public_key:         peer_public_key,
                        ca_private_key:     etcd_key,
                        key_usage:          "keyEncipherment",
                        extended_key_usage: "serverAuth,clientAuth",
                        san:                "DNS:*.kube-etcd.kube-system.svc.cluster.local,DNS:kube-etcd-client.kube-system.svc.cluster.local,DNS:kubernetes.sandbox,IP:172.17.4.101,IP:10.3.0.15,IP:10.3.0.20")

    peer_file = File.new("provisioning/etc/ssl/etcd/peer.crt", "wb")
    peer_file.syswrite(peer_cert.to_pem)
    peer_file.close
    peer_file_tec = File.new("provisioning/tectonic/tls/etcd/peer.crt", "wb")
    peer_file_tec.syswrite(peer_cert.to_pem)
    peer_file_tec.close

    peer_key_file= File.new("provisioning/etc/ssl/etcd/peer.pem", "wb")
    peer_key_file.syswrite(peer_key.to_pem)
    peer_key_file.close
    peer_file_tec = File.new("provisioning/tectonic/tls/etcd/peer.key", "wb")
    peer_file_tec.syswrite(peer_key.to_pem)
    peer_file_tec.close
    # END ETCD PEER

    # BEGIN ETCD CLIENT
    etcd_client_key = OpenSSL::PKey::RSA.new(2048)
    etcd_client_public_key = etcd_client_key.public_key

    etcd_client_cert = signTLS(is_ca:              false,
                               subject:            "/C=/ST=/L=/postalCode=/O=etcd/OU=/CN=etcd",
                               issuer_subject:     "/C=/ST=/L=/postalCode=/O=etcd/OU=/CN=etcd-ca",
                               issuer_cert:        etcd_cert,
                               public_key:         etcd_client_public_key,
                               ca_private_key:     etcd_key,
                               key_usage:          "keyEncipherment",
                               extended_key_usage: "clientAuth")

    etcd_client_file_tec = File.new("provisioning/tectonic/tls/etcd-client.crt", "wb")
    etcd_client_file_tec.syswrite(etcd_client_cert.to_pem)
    etcd_client_file_tec.close

    etcd_client_file_tec = File.new("provisioning/tectonic/tls/etcd-client.key", "wb")
    etcd_client_file_tec.syswrite(etcd_client_key.to_pem)
    etcd_client_file_tec.close
    # END ETCD CLIENT

    # BEGIN KUBE CA
    kube_key = OpenSSL::PKey::RSA.new(2048)
    kube_public_key = kube_key.public_key
    kube_cert = signTLS(is_ca:          true,
                        subject:        "/C=/ST=/L=/postalCode=/O=bootkube/OU=/CN=kube-ca",
                        public_key:     kube_public_key,
                        ca_private_key: kube_key,
                        key_usage:      "digitalSignature,keyEncipherment,keyCertSign")

    kube_file_tls = File.new("provisioning/tectonic/tls/ca.crt", "wb")
    kube_file_tls.syswrite(kube_cert.to_pem)
    kube_file_tls.close
    kube_key_file= File.new("provisioning/tectonic/tls/ca.key", "wb")
    kube_key_file.syswrite(kube_key.to_pem)
    kube_key_file.close
    # END KUBE CA

    # BEGIN KUBE CLIENT (KUBELET)
    client_key = OpenSSL::PKey::RSA.new(2048)
    client_public_key = client_key.public_key

    client_cert = signTLS(is_ca:              false,
                          subject:            "/C=/ST=/L=/postalCode=/O=system:masters/OU=/CN=kubelet",
                          issuer_subject:     "/C=/ST=/L=/postalCode=/O=bootkube/OU=/CN=kube-ca",
                          issuer_cert:        kube_cert,
                          public_key:         client_public_key,
                          ca_private_key:     kube_key,
                          key_usage:          "digitalSignature,keyEncipherment",
                          extended_key_usage: "serverAuth,clientAuth")

    client_file_tls = File.new("provisioning/tectonic/tls/kubelet.crt", "wb")
    client_file_tls.syswrite(client_cert.to_pem)
    client_file_tls.close
    client_key_file= File.new("provisioning/tectonic/tls/kubelet.key", "wb")
    client_key_file.syswrite(client_key.to_pem)
    client_key_file.close
    # END CLIENT

    # START KUBECONFIG
    data = File.read("provisioning/templates/kubeconfig.tmpl")
    data = data.gsub("{{CA_CERT}}", Base64.strict_encode64(kube_cert.to_pem))
    data = data.gsub("{{CLIENT_CERT}}", Base64.strict_encode64(client_cert.to_pem))
    data = data.gsub("{{CLIENT_KEY}}", Base64.strict_encode64(client_key.to_pem))

    kubeconfig_file_etc = File.new("provisioning/etc/kubernetes/kubeconfig", "wb")
    kubeconfig_file_etc.syswrite(data)
    kubeconfig_file_etc.close
    kubeconfig_file_auth = File.new("provisioning/tectonic/auth/kubeconfig", "wb")
    kubeconfig_file_auth.syswrite(data)
    kubeconfig_file_auth.close
    # END KUBECONFIG

    # START APISERVER
    apiserver_key = OpenSSL::PKey::RSA.new(2048)
    apiserver_public_key = apiserver_key.public_key

    apiserver_cert = signTLS(is_ca:              false,
                             subject:            "/C=/ST=/L=/postalCode=/O=kube-master/OU=/CN=kube-apiserver",
                             issuer_subject:     "/C=/ST=/L=/postalCode=/O=bootkube/OU=/CN=kube-ca",
                             issuer_cert:        kube_cert,
                             public_key:         apiserver_public_key,
                             ca_private_key:     kube_key,
                             key_usage:          "digitalSignature,keyEncipherment",
                             extended_key_usage: "serverAuth,clientAuth",
                             san:                "DNS:kubernetes,DNS:kubernetes.default,DNS:kubernetes.default.svc,DNS:kubernetes.default.svc.cluster.local,DNS:kubernetes.sandbox,IP:172.17.4.101,IP:10.3.0.1")

    apiserver_file_tls = File.new("provisioning/tectonic/tls/apiserver.crt", "wb")
    apiserver_file_tls.syswrite(apiserver_cert.to_pem)
    apiserver_file_tls.close
    apiserver_key_file= File.new("provisioning/tectonic/tls/apiserver.key", "wb")
    apiserver_key_file.syswrite(apiserver_key.to_pem)
    apiserver_key_file.close
    # END APISERVER

    # START SERVICE ACCOUNT
    service_account_key = OpenSSL::PKey::RSA.new(2048)
    service_account_pubkey = service_account_key.public_key

    service_account_key_file= File.new("provisioning/tectonic/tls/service-account.key", "wb")
    service_account_key_file.syswrite(service_account_key.to_pem)
    service_account_key_file.close
    service_account_pubkey_file= File.new("provisioning/tectonic/tls/service-account.pub", "wb")
    service_account_pubkey_file.syswrite(service_account_pubkey.to_pem)
    service_account_pubkey_file.close
    # END SERVICE ACCOUNT

    # START TECTONIC INGRESS
    ingress_key = OpenSSL::PKey::RSA.new(2048)
    ingress_public_key = ingress_key.public_key

    ingress_cert = signTLS(is_ca:              false,
                           subject:            "/C=/ST=/L=/postalCode=/O=/OU=/CN=tectonic.sandbox",
                           issuer_subject:     "/C=/ST=/L=/postalCode=/O=bootkube/OU=/CN=kube-ca",
                           issuer_cert:        kube_cert,
                           public_key:         ingress_public_key,
                           ca_private_key:     kube_key,
                           key_usage:          "digitalSignature,keyEncipherment",
                           extended_key_usage: "serverAuth,clientAuth",
                           san:                "DNS:tectonic.sandbox")

    # END TECTONIC INGRESS

    # START BOOTKUBE MANIFESTS
    data = File.read("provisioning/templates/kube-apiserver-secret.tmpl")
    data = data.gsub("{{CA_CRT}}", Base64.strict_encode64(kube_cert.to_pem))
    data = data.gsub("{{APISERVER_CRT}}", Base64.strict_encode64(apiserver_cert.to_pem))
    data = data.gsub("{{APISERVER_KEY}}", Base64.strict_encode64(apiserver_key.to_pem))
    data = data.gsub("{{SERVICE_ACCOUNT_PUB}}", Base64.strict_encode64(service_account_pubkey.to_pem))
    data = data.gsub("{{ETCD_CA_CRT}}", Base64.strict_encode64(etcd_cert.to_pem))
    data = data.gsub("{{ETCD_CLIENT_CRT}}", Base64.strict_encode64(etcd_client_cert.to_pem))
    data = data.gsub("{{ETCD_CLIENT_KEY}}", Base64.strict_encode64(etcd_client_key.to_pem))
    data = data.gsub("{{OIDC_CA_CRT}}", Base64.strict_encode64(kube_cert.to_pem))

    kubeconfig_file_etc = File.new("provisioning/tectonic/manifests/kube-apiserver-secret.yaml", "wb")
    kubeconfig_file_etc.syswrite(data)
    kubeconfig_file_etc.close

    data = File.read("provisioning/templates/kube-controller-manager-secret.tmpl")
    data = data.gsub("{{CA_CRT}}", Base64.strict_encode64(kube_cert.to_pem))
    data = data.gsub("{{SERVICE_ACCOUNT_KEY}}", Base64.strict_encode64(service_account_key.to_pem))


    kubeconfig_file_etc = File.new("provisioning/tectonic/manifests/kube-controller-manager-secret.yaml", "wb")
    kubeconfig_file_etc.syswrite(data)
    kubeconfig_file_etc.close
    # END BOOTKUBE MANIFESTS

    # START TECTONIC IDENTITY CLIENT
    identity_client_key = OpenSSL::PKey::RSA.new(2048)
    identity_client_public_key = identity_client_key.public_key

    identity_client_cert = signTLS(is_ca:              false,
                                   subject:            "/C=/ST=/L=/postalCode=/O=/OU=/CN=tectonic-identity-api.tectonic-system.svc.cluster.local",
                                   issuer_subject:     "/C=/ST=/L=/postalCode=/O=bootkube/OU=/CN=kube-ca",
                                   issuer_cert:        kube_cert,
                                   public_key:         identity_client_public_key,
                                   ca_private_key:     kube_key,
                                   extended_key_usage: "clientAuth")

    # END TECTONIC IDENTITY CLIENT

    # START TECTONIC IDENTITY SERVER
    identity_server_key = OpenSSL::PKey::RSA.new(2048)
    identity_server_public_key = identity_server_key.public_key

    identity_server_cert = signTLS(is_ca:              false,
                                   subject:            "/C=/ST=/L=/postalCode=/O=/OU=/CN=tectonic-identity-api.tectonic-system.svc.cluster.local",
                                   issuer_subject:     "/C=/ST=/L=/postalCode=/O=bootkube/OU=/CN=kube-ca",
                                   issuer_cert:        kube_cert,
                                   public_key:         identity_server_public_key,
                                   ca_private_key:     kube_key,
                                   extended_key_usage: "serverAuth")

    # END TECTONIC IDENTITY SERVER

    # START TECTONIC MANIFESTS
    data = File.read("provisioning/templates/config.tmpl")
    data = data.gsub("{{UUID}}", SecureRandom.uuid)
    data = data.gsub("{{OS}}", case RbConfig::CONFIG["host_os"]
                               when /cygwin|mswin|mingw|bccwin|wince|emx/ then "windows"
                               when /darwin|mac os/ then "macos"
                               when /linux/ then "linux"
                               else RbConfig::CONFIG["host_os"]
                               end)

    config_file = File.new("provisioning/tectonic/tectonic/config.yaml", "wb")
    config_file.syswrite(data)
    config_file.close

    data = File.read("provisioning/templates/ingress-tls.tmpl")
    data = data.gsub("{{INGRESS_CRT}}", Base64.strict_encode64(ingress_cert.to_pem))
    data = data.gsub("{{INGRESS_KEY}}", Base64.strict_encode64(ingress_key.to_pem))

    ingress_file_etc = File.new("provisioning/tectonic/tectonic/secrets/ingress-tls.yaml", "wb")
    ingress_file_etc.syswrite(data)
    ingress_file_etc.close

    ingress_certificate_pem = File.new("tectonic.sandbox.pem","wb")
    ingress_certificate_pem.syswrite(ingress_cert.to_pem)
    ingress_certificate_pem.close

    data = File.read("provisioning/templates/ca-cert.tmpl")
    data = data.gsub("{{CA_CRT}}", Base64.strict_encode64(kube_cert.to_pem))

    tec_ca_file_etc = File.new("provisioning/tectonic/tectonic/secrets/ca-cert.yaml", "wb")
    tec_ca_file_etc.syswrite(data)
    tec_ca_file_etc.close

    data = File.read("provisioning/templates/identity-grpc-client.tmpl")
    data = data.gsub("{{CLIENT_CRT}}", Base64.strict_encode64(identity_client_cert.to_pem))
    data = data.gsub("{{CLIENT_KEY}}", Base64.strict_encode64(identity_client_key.to_pem))
    data = data.gsub("{{CA_CRT}}", Base64.strict_encode64(kube_cert.to_pem))

    identity_client_file_etc = File.new("provisioning/tectonic/tectonic/secrets/identity-grpc-client.yaml", "wb")
    identity_client_file_etc.syswrite(data)
    identity_client_file_etc.close

    data = File.read("provisioning/templates/identity-grpc-server.tmpl")
    data = data.gsub("{{SERVER_CRT}}", Base64.strict_encode64(identity_server_cert.to_pem))
    data = data.gsub("{{SERVER_KEY}}", Base64.strict_encode64(identity_server_key.to_pem))
    data = data.gsub("{{CA_CRT}}", Base64.strict_encode64(kube_cert.to_pem))

    identity_server_file_etc = File.new("provisioning/tectonic/tectonic/secrets/identity-grpc-server.yaml", "wb")
    identity_server_file_etc.syswrite(data)
    identity_server_file_etc.close

    data = File.read("provisioning/templates/configmap.tmpl")
    data = data.gsub("{{CONSOLE_SECRET}}", Base64.urlsafe_encode64(SecureRandom.random_bytes(16), padding: false))
    data = data.gsub("{{KUBECTL_SECRET}}", Base64.urlsafe_encode64(SecureRandom.random_bytes(16), padding: false))
    data = data.gsub("{{USER_ID}}",        Base64.urlsafe_encode64(SecureRandom.random_bytes(16), padding: false))

    configmap_file = File.new("provisioning/tectonic/tectonic/identity/configmap.yaml", "wb")
    configmap_file.syswrite(data)
    configmap_file.close

    data = File.read("provisioning/templates/tectonic-monitoring-auth-secret.tmpl")
    # the cookie secret gets encoded with base64 twice for some reason; once URL safe and a second time normally
    data = data.gsub("{{COOKIE_SECRET}}", Base64.strict_encode64(Base64.urlsafe_encode64(SecureRandom.random_bytes(16), padding: false)))
    
  end
  config.vm.provision :file, :source => "provisioning/etc", :destination => "/tmp/etc"
  config.vm.provision :shell, :inline => "cp -r /tmp/etc/* /etc && rm -rf /tmp/etc", :privileged => true

  config.vm.provision :file, :source => "provisioning/tectonic", :destination => "/tmp/tectonic"
  config.vm.provision :shell, :inline => "mkdir /opt; mv /tmp/tectonic /opt/tectonic", :privileged => true

  config.vm.provision :shell, :inline => "systemctl restart etcd-member", :privileged => true

  config.vm.provision :file, :source => "provisioning/tectonic-startup.sh", :destination => "/tmp/tectonic-startup.sh"
  config.vm.provision :shell, :inline => "chmod +x /tmp/tectonic-startup.sh && /tmp/tectonic-startup.sh && rm /tmp/tectonic-startup.sh", :privileged => true
end

def cleanup config
  FileUtils.rm_rf('provisioning/etc')
end