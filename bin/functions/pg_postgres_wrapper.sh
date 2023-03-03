# Postgres wrapper stuff
pg() {
  case $1 in
  start)
    >&2 echo -e "${ANSI}${TXTYLW}pg_ctl -l $PGDATA/server.log start${ANSI}${TXTDFT}"
    pg_ctl -l $PGDATA/server.log start
    ;;
  stop)
    >&2 echo -e "${ANSI}${TXTYLW}pg_ctl stop -m fast${ANSI}${TXTDFT}"
    ;;
  status)
    >&2 echo -e "${ANSI}${TXTYLW}pg_ctl status${ANSI}${TXTDFT}"
    ;;
  restart)
    >&2 echo -e "${ANSI}${TXTYLW}pg_ctl reload${ANSI}${TXTDFT}"
    ;;
  *)
    echo "Usage: pg start|stop|status|restart"
    echo "This function is defined in $BASH_SOURCE"
    ;;
  esac
}
