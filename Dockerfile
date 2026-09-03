# Strike Search.
#
# Forked from protemplate/searxng. See entrypoint.sh for the runtime changes.

# Pinned. Upstream used :latest, which rebuilds daily. A redeploy months from
# now -- triggered by an unrelated config change, or by Railway recreating the
# service -- would then quietly ship a different SearXNG than the one that was
# tested. Bump this line on purpose, and re-test when you do.
FROM docker.io/searxng/searxng:2026.8.22-9fea41204

# Railway injects these at build time. None of them are secrets.
ARG SEARXNG_BASE_URL
ARG SEARXNG_UWSGI_WORKERS
ARG SEARXNG_UWSGI_THREADS
ARG PORT

ENV BASE_URL=${SEARXNG_BASE_URL}
ENV PORT=${PORT:-8080}
ENV UWSGI_WORKERS=${SEARXNG_UWSGI_WORKERS:-4}
ENV UWSGI_THREADS=${SEARXNG_UWSGI_THREADS:-4}

# Copied twice on purpose. The Railway service mounts a volume at
# /etc/searxng, and a volume mount hides whatever the image put at that path.
# The -backup copy is outside the mount, so entrypoint.sh can always reach the
# config the image was built with and sync it in.
COPY ./searxng /etc/searxng
COPY ./searxng /etc/searxng-backup

# Strike's branding: templates, logo, and a CSS file that overrides the
# colour variables SearXNG's own stylesheet defines, loaded after it so these
# values win without patching the minified file directly. Baked into the
# image here rather than left as a live edit in the running container, so a
# redeploy doesn't quietly revert to stock SearXNG branding. See overlay/.
COPY overlay/searx/templates/simple/base.html /usr/local/searxng/searx/templates/simple/base.html
COPY overlay/searx/templates/simple/index.html /usr/local/searxng/searx/templates/simple/index.html
COPY overlay/searx/templates/simple/search.html /usr/local/searxng/searx/templates/simple/search.html
COPY overlay/searx/templates/simple/page_with_header.html /usr/local/searxng/searx/templates/simple/page_with_header.html
COPY overlay/searx/static/themes/simple/strike-brand.css /usr/local/searxng/searx/static/themes/simple/strike-brand.css
COPY overlay/searx/static/themes/simple/img/favicon.png /usr/local/searxng/searx/static/themes/simple/img/favicon.png
COPY overlay/searx/static/themes/simple/img/favicon.svg /usr/local/searxng/searx/static/themes/simple/img/favicon.svg
COPY overlay/searx/static/themes/simple/img/searxng.svg /usr/local/searxng/searx/static/themes/simple/img/searxng.svg
COPY overlay/searx/static/themes/simple/img/searxng.png /usr/local/searxng/searx/static/themes/simple/img/searxng.png
COPY overlay/searx/static/themes/simple/img/strike-mark.png /usr/local/searxng/searx/static/themes/simple/img/strike-mark.png
COPY overlay/searx/static/themes/simple/img/192.png /usr/local/searxng/searx/static/themes/simple/img/192.png
COPY overlay/searx/static/themes/simple/img/512.png /usr/local/searxng/searx/static/themes/simple/img/512.png

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# SEARXNG_SECRET_KEY stays in the environment and never in this repo.
ENTRYPOINT ["/entrypoint.sh"]
