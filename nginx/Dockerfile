FROM alpine:latest as nginx

RUN apk --update add nginx &&\
    mv -v /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak

COPY nginx.conf /etc/nginx/nginx.conf

CMD ["nginx", "-g", "daemon off;"]






