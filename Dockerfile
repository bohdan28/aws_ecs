FROM alpine/ollama:0.10.1

COPY /models /root/.ollama/models/

EXPOSE 11434

CMD ["ollama", "serve"]
