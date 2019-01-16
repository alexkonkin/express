FROM alpine:latest as nginx

RUN apk --update add nginx gettext &&\
    mv -v /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak

#COPY nginx.conf /etc/nginx/nginx.conf
COPY nginx.tmpl /etc/nginx/nginx.tmpl
COPY start.sh /usr/local/bin

#CMD ["nginx", "-g", "daemon off;"]
CMD ["/usr/local/bin/start.sh"]






