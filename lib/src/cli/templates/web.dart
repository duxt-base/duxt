/// Tailwind CSS template
const tailwindTemplate = '''
@import "tailwindcss";

@source "../lib/**/*.dart";
@source "../.duxt/packages/**/*.dart";

@theme {
  --color-primary-50: #ecfeff;
  --color-primary-100: #cffafe;
  --color-primary-200: #a5f3fc;
  --color-primary-300: #67e8f9;
  --color-primary-400: #22d3ee;
  --color-primary-500: #06b6d4;
  --color-primary-600: #0891b2;
  --color-primary-700: #0e7490;
  --color-primary-800: #155e75;
  --color-primary-900: #164e63;
  --color-primary-950: #083344;
}

@layer base {
  html { font-family: system-ui, -apple-system, sans-serif; }
  body { @apply bg-white text-gray-900 dark:bg-gray-950 dark:text-gray-100; }
}
''';

/// Index.html template
String indexHtmlTemplate(String title) => '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>$title</title>
  <link rel="stylesheet" href="/styles.css">
</head>
<body>
  <div id="app"></div>
  <script type="module" src="/main.client.dart.js"></script>
</body>
</html>
''';

/// Web entry point for client mode (webdev needs entry point in web/)
String webMainClientTemplate(String projectName) => '''
import 'package:$projectName/main.client.dart' as app;

void main() => app.main();
''';

/// Dockerfile template
const dockerfileTemplate = r'''
# Build stage
FROM dart:stable AS build
WORKDIR /app

RUN dart pub global activate jaspr_cli && \
    apt-get update && apt-get install -y curl && \
    ARCH=$(dpkg --print-architecture) && \
    if [ "$ARCH" = "arm64" ]; then TW_ARCH="arm64"; else TW_ARCH="x64"; fi && \
    curl -sLO https://github.com/tailwindlabs/tailwindcss/releases/latest/download/tailwindcss-linux-$TW_ARCH && \
    chmod +x tailwindcss-linux-$TW_ARCH && mv tailwindcss-linux-$TW_ARCH /usr/local/bin/tailwindcss

COPY pubspec.* ./
RUN dart pub get
COPY . .

RUN mkdir -p .duxt/packages/duxt_ui && cp -r /root/.pub-cache/hosted/pub.dev/duxt_ui-*/lib/* .duxt/packages/duxt_ui/
RUN tailwindcss --input web/styles.tw.css --output web/styles.css --minify
RUN ~/.pub-cache/bin/jaspr build
RUN dart build cli -t server/main.dart -o /app/.output

# Runtime stage
FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y ca-certificates libsqlite3-0 nginx supervisor && rm -rf /var/lib/apt/lists/*
WORKDIR /app

COPY --from=build /app/.output/bundle /app
COPY --from=build /app/build/jaspr /var/www/html

RUN echo 'server { listen 3000; root /var/www/html; index index.html; location /api { proxy_pass http://127.0.0.1:3001; } location / { try_files $uri $uri/ /index.html; } }' > /etc/nginx/sites-available/default
RUN echo '[supervisord]\nnodaemon=true\n[program:nginx]\ncommand=nginx -g "daemon off;"\n[program:api]\ncommand=/app/bin/main\ndirectory=/app\nenvironment=PORT="3001",DATA_DIR="/app/data"' > /etc/supervisor/conf.d/app.conf
RUN mkdir -p /app/data

ENV PORT=3001 DATA_DIR=/app/data
EXPOSE 3000
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/supervisord.conf"]
''';

/// Docker ignore template
const dockerignoreTemplate = '''
.git
.gitignore
.dart_tool
build
.output
.duxt
.idea
.vscode
*.iml
*.db
*.db-journal
.DS_Store
Thumbs.db
*.log
''';

/// Docker compose template
const dockerComposeTemplate = '''
services:
  app:
    build: .
    ports:
      - "3000:3000"
    volumes:
      - app-data:/app/data
    restart: unless-stopped

volumes:
  app-data:
''';
