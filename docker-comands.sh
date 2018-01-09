
# Creating database dumps
#
# docker exec some-mysql sh -c 'exec mysqldump --all-databases -uroot -p"$MYSQL_ROOT_PA
# docker run -it --rm -v /bkpmysql:/bkpmysql mysql:5.7 sh -c 'exec mysqldump -h host -uroot -p glpi > /bkpmysql/glpi.sql'
