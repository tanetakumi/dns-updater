FROM alpine:3.19

RUN apk add --no-cache curl bash tzdata

WORKDIR /app

COPY entrypoint.sh .
RUN chmod +x entrypoint.sh

ENTRYPOINT ["./entrypoint.sh"]