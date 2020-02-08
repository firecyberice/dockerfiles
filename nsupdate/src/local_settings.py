import os
#from nsupdate.settings.prod import *
from nsupdate.settings.dev import *
#from .base import *

"""
settings for production
"""

STATIC_ROOT = '/var/www/static'

DEBUG = True

WE_HAVE_TLS = False  # True if you run a https site also, suggest that site to users if they work on the http site.
CSRF_COOKIE_SECURE = WE_HAVE_TLS
SESSION_COOKIE_SECURE = WE_HAVE_TLS

# these are the service host names we deal with
BASEDOMAIN = os.environ['BASEDOMAIN']
# do NOT just use the BASEDOMAIN for WWW_HOST, or you will run into troubles
# when you want to be on publicsuffix.org list and still be able to set cookies
#WWW_HOST = 'www.' + BASEDOMAIN  # a host with a ipv4 and a ipv6 address
# hosts to enforce a v4 / v6 connection (to determine the respective ip)
#WWW_IPV4_HOST = 'ipv4.' + BASEDOMAIN  # a host with ONLY a ipv4 address
#WWW_IPV6_HOST = 'ipv6.' + BASEDOMAIN  # a host with ONLY a ipv6 address

WWW_HOST = BASEDOMAIN
WWW_IPV4_HOST = BASEDOMAIN
WWW_IPV6_HOST = BASEDOMAIN

# Hosts/domain names that are valid for this site; required if DEBUG is False
# See https://docs.djangoproject.com/en/1.6/ref/settings/#allowed-hosts
ALLOWED_HOSTS = ['*']
# ALLOWED_HOSTS = [WWW_HOST, WWW_IPV4_HOST, WWW_IPV6_HOST]


# service contact for showing on the "about" page:
#SERVICE_CONTACT = 'your_email AT example DOT com'

# sender address for e.g. user activation emails
#DEFAULT_FROM_EMAIL = "noreply@firecyberice.de"

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.sqlite3',  # Add 'postgresql_psycopg2', 'mysql', 'sqlite3' or 'oracle'.
        'NAME': 'data/nsupdate.sqlite',               # Or path to database file if using sqlite3.
        # The following settings are not used with sqlite3:
        'USER': '',
        'PASSWORD': '',
        'HOST': '',             # Empty for localhost through domain sockets or '127.0.0.1' for localhost through TCP.
        'PORT': ''              # Set to empty string for default.
    }
}


TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [
            # '/where/you/have/additional/templates',
        ],

        'OPTIONS': {
            'context_processors': [
                # Insert your TEMPLATE_CONTEXT_PROCESSORS here or use this
                # list if you haven't customized them:
                'django.contrib.auth.context_processors.auth',
                # 'django.template.context_processors.debug',
                'django.template.context_processors.i18n',
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'nsupdate.context_processors.add_settings',
                'nsupdate.context_processors.update_ips',
                # 'django.template.context_processors.media',
                # 'django.template.context_processors.static',
                # 'django.template.context_processors.tz',
                # 'django.contrib.messages.context_processors.messages',
                'social_django.context_processors.backends',
                'social_django.context_processors.login_redirect',
            ],
            'loaders': [
                'django.template.loaders.filesystem.Loader',
                'django.template.loaders.app_directories.Loader',
            ],
        },
    },
]

MIDDLEWARE_CLASSES = (
    'django.middleware.common.CommonMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.locale.LocaleMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'social_django.middleware.SocialAuthExceptionMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
)

INSTALLED_APPS = (
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.sites',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'django.contrib.humanize',
    'social_django',
    'nsupdate.login',
    'nsupdate',
    'nsupdate.accounts',
    'nsupdate.api',
    'nsupdate.main',
    'bootstrapform',
    'django.contrib.admin',
    'registration',
    'django_extensions',
)

# python-social-auth settings

AUTHENTICATION_BACKENDS = (
    'django.contrib.auth.backends.ModelBackend',
    'social_core.backends.google.GoogleOAuth2',
#    'social_core.backends.github.GithubOAuth2',
#    'social_core.backends.amazon.AmazonOAuth2',
#    'social_core.backends.bitbucket.BitbucketOAuth',
#    'social_core.backends.disqus.DisqusOAuth2',
#    'social_core.backends.dropbox.DropboxOAuth',
#    'social_core.backends.reddit.RedditOAuth2',
#    'social_core.backends.soundcloud.SoundcloudOAuth2',
#    'social_core.backends.stackoverflow.StackoverflowOAuth2',
#    'social_core.backends.twitter.TwitterOAuth',
)
