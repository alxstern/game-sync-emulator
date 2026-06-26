import NIOSSL

// Provides the pre-generated TLS certificate chain and private key for the HTTPS server.
//
// The server cert is signed by the Nintendo Wii NWC Prod 1 CA, which the DS trusts.
// Generated once via OpenSSL using the issuer cert/key embedded in the original Java source:
//   openssl genrsa -out server_key.pem 1024
//   openssl req -new -key server_key.pem -subj "/CN=*.*.*" | \
//     openssl x509 -req -CA nintendo_ca.pem -CAkey nintendo_ca_key.pem \
//       -set_serial 1 -days 18250 -sha1 -extfile <(echo authorityKeyIdentifier=keyid,issuer)
enum CertificateGenerator {

    // RSA-1024, CN=*.*.*, signed by Nintendo Wii NWC Prod 1 CA, valid 50 years
    private nonisolated static var serverCertPEM: String { """
    -----BEGIN CERTIFICATE-----
    MIICXzCCAcigAwIBAgIBATANBgkqhkiG9w0BAQUFADCBlDELMAkGA1UEBhMCVVMx
    EzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxITAfBgNVBAoT
    GE5pbnRlbmRvIG9mIEFtZXJpY2EgSW5jLjEXMBUGA1UEAxMOV2lpIE5XQyBQcm9k
    IDExIjAgBgkqhkiG9w0BCQEWE2NhQG5vYS5uaW50ZW5kby5jb20wIBcNMjYwNjI2
    MDIwMzIwWhgPMjA3NjA2MTMwMjAzMjBaMBAxDjAMBgNVBAMMBSouKi4qMIGfMA0G
    CSqGSIb3DQEBAQUAA4GNADCBiQKBgQDFi5F0r+SwdrOxeEgWY1YgaSv29SVUH18Y
    0r6zXc6vRRkEZPNVP+fgFd2bKUbf0ZRnG0kssVfUIMWgEmNYlH0k8lB93CVF9Bkn
    9kvAggN1dM+PWX+0qjbVlH59HGMhUtFQxIL9c9Oiqx/vEA+Wx2N30k0tLdZJjmnu
    ga9y/8NkmwIDAQABo0IwQDAfBgNVHSMEGDAWgBS4jMx5zcEOQatgarpRTzO/6R4m
    nTAdBgNVHQ4EFgQUrqjXVlGd1Gf6ksQksHFIzTkyaVUwDQYJKoZIhvcNAQEFBQAD
    gYEAiSmBMwFiK/ySbsT4YiWf1T6uVhVMLLNHOJ7NplnFclLuMYWT0XeL0GpUHhdy
    lUIGN+tF6UbcqfM0grpn+nPLSPMIqoeKpRjrxFz5GHy6m2/ByJ2FBKocmP+zpYpW
    yQNQdEcu3aMxAbr0wKerCxmC4NdoULU6bysD+w6QNZSRchs=
    -----END CERTIFICATE-----
    """ }

    // Nintendo Wii NWC Prod 1 CA — the DS validates the full chain up to this cert
    private nonisolated static var caCertPEM: String { """
    -----BEGIN CERTIFICATE-----
    MIID6TCCA1KgAwIBAgIBGjANBgkqhkiG9w0BAQUFADCBjDELMAkGA1UEBhMCVVMx
    EzARBgNVBAgTCldhc2hpbmd0b24xIDAeBgNVBAoTF05pbnRlbmRvIG9mIEFtZXJp
    Y2EgSW5jMQwwCgYDVQQLEwNOT0ExFDASBgNVBAMTC05pbnRlbmRvIENBMSIwIAYJ
    KoZIhvcNAQkBFhNjYUBub2EubmludGVuZG8uY29tMB4XDTA2MDcxMjE2MzQzOVoX
    DTM2MDcwNDE2MzQzOVowgZQxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5n
    dG9uMRAwDgYDVQQHEwdSZWRtb25kMSEwHwYDVQQKExhOaW50ZW5kbyBvZiBBbWVy
    aWNhIEluYy4xFzAVBgNVBAMTDldpaSBOV0MgUHJvZCAxMSIwIAYJKoZIhvcNAQkB
    FhNjYUBub2EubmludGVuZG8uY29tMIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKB
    gQDZ50PR9MIRE2S18jR7M5Okk8b4wVx3yXacyBhjfYSSPRbJKHLjRD4Ttno7mJb4
    HfGeE202RT9zsAw+6H069v/Uv6MXRL+CgKPAF7cuZ6TUMaRk0Ld7vWtiPuajZVYu
    kQmgMCI2liNCIv/BXnAaeRRPz+3hEAT+iFr/OPlVPTgO9QIDAQABo4IBTzCCAUsw
    CQYDVR0TBAIwADAsBglghkgBhvhCAQ0EHxYdT3BlblNTTCBHZW5lcmF0ZWQgQ2Vy
    dGlmaWNhdGUwHQYDVR0OBBYEFLiMzHnNwQ5Bq2BqulFPM7/pHiadMIG5BgNVHSME
    gbEwga6AFHtXUz8xrHdx8f1K5g9DsNVVQZ/SoYGSpIGPMIGMMQswCQYDVQQGEwJV
    UzETMBEGA1UECBMKV2FzaGluZ3RvbjEgMB4GA1UEChMXTmludGVuZG8gb2YgQW1l
    cmljYSBJbmMxDDAKBgNVBAsTA05PQTEUMBIGA1UEAxMLTmludGVuZG8gQ0ExIjAg
    BgkqhkiG9w0BCQEWE2NhQG5vYS5uaW50ZW5kby5jb22CAQAwNQYDVR0fBC4wLDAq
    oCigJoYkaHR0cDovL2NybC5uaW50ZW5kby5jb20vbmludGVuZG8uY3JsMA0GCSqG
    SIb3DQEBBQUAA4GBAGWj4GGqRmcfJRD8niRtTnB/KvcfG947ErBi1QI4wLWggOaD
    RS65M2ygJATLe6r1fWpeQr59eitrZuO1xDaAaZJcBl+5hrTGcarmgD9PV+sh8xTF
    rVox8bTKe35+7+q00t6ztw2FLG6ssxY9eqAntktzhPUEJ5UFZdJ1+zQWWdDx
    -----END CERTIFICATE-----
    """ }

    // RSA-1024 private key (PKCS8) corresponding to serverCertPEM
    private nonisolated static var serverKeyPEM: String { """
    -----BEGIN PRIVATE KEY-----
    MIICdgIBADANBgkqhkiG9w0BAQEFAASCAmAwggJcAgEAAoGBAMWLkXSv5LB2s7F4
    SBZjViBpK/b1JVQfXxjSvrNdzq9FGQRk81U/5+AV3ZspRt/RlGcbSSyxV9QgxaAS
    Y1iUfSTyUH3cJUX0GSf2S8CCA3V0z49Zf7SqNtWUfn0cYyFS0VDEgv1z06KrH+8Q
    D5bHY3fSTS0t1kmOae6Br3L/w2SbAgMBAAECgYEAmI0pbMUQg72HEvviH3fi4PCX
    BQVXKFl5pL/KiNVecTeZFC2pRCIvvHrmQZZkpx8/zUfjAGKLgsM0GmNY2OUCphN/
    M2RYy1JLJJou6qXQWh1I6vJ1Up0BP6EtfTOraEqvkueq0UUgD49owbUvA2h0dLc9
    zI0h/4MLAE49xGxFwrECQQDvcvsFDyk+ij77EAko7oSLBsIKr4USLQAUiuvEkPgy
    xOqQmy/wh+5hdzrBDRhI49qboQzZQg7uC0mZOmD1ZzYvAkEA0zMaW8OsgDDhz+gJ
    rEkc1MRcEOiU6OainHwRnYqTcJjpExvjZ8rJBO98AAQPJ112+XRQbhSDmifQzC5c
    wuVJVQJAIB90vYEDL3isalIEaJFXBq+paHWTjJSs5hSc/InWQjlYnn2zOLmDqV+t
    aiivkVfABBDfAGZ0SksJXJ0QVNu70QJAdgZI5J8k9z5Z8uWpAi6Zfg19pbVUAhNh
    LDHpZjDa1EGffp5HJumcDLYIhbm+/jCtHBp0GBA+uxclB/WgwQmBQQJAd5pZEvbk
    7MwZHJ7ETk3vm4GjF+F5n1QEvO7WzxKEf+bPOJZYeaqMONyDagQ/TKTwFSuhI/62
    qPbo4mGr2jsfnA==
    -----END PRIVATE KEY-----
    """ }

    nonisolated static func load() throws -> (certificateChain: [NIOSSLCertificate], privateKey: NIOSSLPrivateKey) {
        let serverCert = try NIOSSLCertificate(bytes: Array(serverCertPEM.utf8), format: .pem)
        let caCert    = try NIOSSLCertificate(bytes: Array(caCertPEM.utf8),    format: .pem)
        let key       = try NIOSSLPrivateKey(bytes:  Array(serverKeyPEM.utf8),  format: .pem)
        return (certificateChain: [serverCert, caCert], privateKey: key)
    }
}
