FROM alpine/ollama:0.10.1

COPY /models /root/.ollama/models/

EXPOSE 11434

ENTRYPOINT ["/usr/bin/ollama"]
CMD ["serve"]