FROM scratch
EXPOSE 8080
ENTRYPOINT ["/jenkins-kaniko-example"]
COPY ./bin/ /