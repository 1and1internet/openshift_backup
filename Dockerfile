FROM alpine:3.7
MAINTAINER james.eckersall@1and1.co.uk

RUN apk update
RUN apk add ruby bash curl tar supervisor 
RUN apk del build-base
RUN rm -rf /var/cache/apk/* 
RUN gem install sinatra -v 1.4.7 --no-rdoc --no-ri
RUN curl -L https://github.com/openshift/origin/releases/download/v1.5.1/openshift-origin-client-tools-v1.5.1-7b451fc-linux-32bit.tar.gz | tar --strip-components=1 --wildcards -zxC /usr/local/bin "*/oc"

COPY files /

RUN mkdir -p /etc/periodic/15min /etc/periodic/hourly /etc/periodic/daily /etc/periodic/weekly /etc/periodic/monthly
RUN chmod +x /etc/periodic/15min/* /etc/periodic/hourly/* /etc/periodic/daily/* /etc/periodic/weekly/* /etc/periodic/monthly/* 2>/dev/null || true

RUN chmod +x /backup-cleaner.py
RUN echo "0	0	*	*	*	/backup-cleaner.py -e 60 -d /backup-data -r 1 -v" >> /etc/crontabs/root

ENTRYPOINT ["supervisord", "--nodaemon", "--configuration", "/etc/supervisord.conf"]
