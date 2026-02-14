server {
    listen {{ .ingress_interface }}:{{ .ingress_port }} default_server;

    include /etc/nginx/includes/server_params.conf;

    include /etc/nginx/includes/proxy_params.conf;

    client_max_body_size 0;

    add_header X-Frame-Options    "SAMEORIGIN"  always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection   "1; mode=block" always;
    add_header Referrer-Policy    "no-referrer"  always;

    location / {
        allow 172.30.32.2;
        deny  all;

        proxy_pass http://127.0.0.1:{{ .app_port }};

        proxy_buffering off;

        proxy_pass_request_headers on;

        proxy_http_version 1.1;
        proxy_set_header   Upgrade    $http_upgrade;
        proxy_set_header   Connection $connection_upgrade;

        proxy_connect_timeout 600s;
        proxy_send_timeout    600s;
        proxy_read_timeout    600s;
    }

    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
