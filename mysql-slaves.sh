#!/bin/bash

# /etc/mysql-slaves/run/-ban levo label-ekkel beindexelunk a /etc/mysql-slaves/$label.cnf-be
# aztan azokat inditjuk, meg leallitjuk

# /etc/init.d/mysql-slaves start [ $label ]

mysqld=/usr/bin/mysqld_safe
mysqladmin=/usr/bin/mysqladmin
slave_cnf_dir=/etc/mysql-slaves/
slave_run_dir=/var/run/mysql-slaves/

start_mysql() {
	pidfile="${slave_run_dir}mysqld.pid.$1"

	if test -f "$pidfile"; then
		echo "mysql-slave $1 already running, not starting"
	else
		echo "mysql-slave $1 starting"
		$mysqld --defaults-file="$slave_cnf_dir$1.cnf" >/dev/null 2>&1 &
	fi
}

stop_mysql() {
	pidfile="${slave_run_dir}mysqld.pid.$1"

	if test -f "$pidfile"; then
		echo "mysql-slave $1 stopping"
		$mysqladmin --defaults-file="$slave_cnf_dir$1.cnf" shutdown >/dev/null 2>&1
	else
		echo "mysql-slave $1 not running"
	fi
}

status_mysql() {
	pidfile="${slave_run_dir}mysqld.pid.$1"
	sockfile="${slave_run_dir}mysqld.sock.$1"

	if test -f "$pidfile" -a -S "$sockfile"; then
		echo "mysql-slave $1 status"
		$mysqladmin --defaults-file="$slave_cnf_dir$1.cnf" status
	else
		echo "mysql-slave $1 not running"
	fi
}

all_slaves() {
	find $slave_cnf_dir -type f -name '*.cnf' -printf "%f\n" | sed 's/\.cnf$//'
}

case "$1" in
	start)
		if test -z "$2"; then
			 all_slaves | while read l; do
				start_mysql "$l"
			done
		else
			start_mysql "$2"
		fi
	;;
	stop)
		if test -z "$2"; then
			all_slaves | while read l; do 
				stop_mysql "$l"
			done
		else
			stop_mysql "$2"
		fi
	;;
	status)
		if test -z "$2"; then
			all_slaves | while read l; do 
				status_mysql "$l"
				echo
			done
		else
			status_mysql "$2"
		fi
	;;
	list)
		all_slaves 
	;;
	*)
		echo "$0 <start|stop|status|list> [slave]"
		exit 1
	;;
esac


