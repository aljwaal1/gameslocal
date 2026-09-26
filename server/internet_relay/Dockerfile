FROM dart:stable AS build
WORKDIR /app
COPY server.dart /app/server.dart
RUN dart compile exe /app/server.dart -o /app/server

FROM debian:bookworm-slim
COPY --from=build /runtime/ /
COPY --from=build /app/server /app/server
ENV PORT=8080
EXPOSE 8080
CMD ["/app/server"]
