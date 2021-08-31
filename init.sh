#install
sudo apt-get update
sudo apt-get install python3-pip python3-dev libpq-dev postgresql postgresql-contrib nginx
export $(cat initer.env)

#init DB
sudo -u postgres psql -c  "CREATE DATABASE $DB_NEW_NAME;"
sudo -u postgres psql -c  "CREATE USER $DB_NEW_USER WITH PASSWORD '$DB_NEW_PASSWORD';"
sudo -u postgres psql -c  "ALTER ROLE $DB_NEW_USER SET client_encoding TO 'utf8';"
sudo -u postgres psql -c  "ALTER ROLE $DB_NEW_USER SET default_transaction_isolation TO 'read committed';"
sudo -u postgres psql -c  "ALTER ROLE $DB_NEW_USER SET timezone TO 'UTC';"
sudo -u postgres psql -c  "GRANT ALL PRIVILEGES ON DATABASE $DB_NEW_NAME TO $DB_NEW_USER;"

#create venv
sudo -H pip3 install --upgrade pip
sudo -H pip3 install virtualenv
virtualenv venv

#install pip packeges
venv/bin/pip install -r requirements.txt
venv/bin/pip install gunicorn
venv/bin/pip install psycopg2
#migration project
venv/bin/python manage.py makemigrations
venv/bin/python manage.py migrate

#create staticfiles
venv/bin/python manage.py collectstatic --noinput

#service create
echo "
[Unit]
Description=gunicorn daemon
After=network.target

[Service]
User=$USER
Group=www-data
WorkingDirectory=$(pwd)
ExecStart=$(pwd)/venv/bin/gunicorn --access-logfile - --workers 3 --bind unix:$(pwd)/$SERVICE_NAME.sock $WSGI_FOLDER_NAME.wsgi:application

[Install]
WantedBy=multi-user.target
" > /etc/systemd/system/$SERVICE_NAME.service

#run service
sudo systemctl start $SERVICE_NAME
sudo systemctl enable $SERVICE_NAME

#init nginx
echo "
server {
    server_name $DOMAIN;

    client_max_body_size 10M;

    location /static {
        alias $(pwd)/$STATICFILE_DIR_NAME;
    }

    location /media {
        alias $(pwd)/$MEDIA_DIR_NAME;
    }

    location / {
        include proxy_params;
        proxy_pass http://unix:$(pwd)/$SERVICE_NAME.sock;
    }

}
" > /etc/nginx/sites-available/$DOMAIN

sudo ln -s /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/

#restart nginx
sudo systemctl restart nginx
