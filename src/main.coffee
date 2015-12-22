remote  = require 'remote'
util    = remote.require("util")
path    = remote.require("path")
exec    = remote.require('child_process').exec

$       = require("./js/lib/jquery-2.1.4.min.js")
ECT     = remote.require('ect')
_       = remote.require("underscore")

# from https://github.com/jprichardson/node-fs-extra
fs      = remote.require('fs-extra')
# from https://www.npmjs.com/package/npm-which
which = require('npm-which')(__dirname) # __dirname often good enough

# src
template_dir   = path.join(__dirname, '/nginx-gui.d/');

# dist
conf_path = path.join(process.env.HOME, '/.nginx-gui.d/');

nginx_conf_dir = path.join(conf_path, '/nginx.d/');
mysql_conf_dir = path.join(conf_path, '/mysql.d/');
app_conf_file  = path.join(conf_path, "settings.json");

###
 入力された文字列の書式が不適切な場合に使用する例外オブジェクト。
 from http://tomoyamkung.net/2014/05/22/javascript-error-object/
 @param {String} message 例外エラーメッセージ。メッセージを指定しない場合はデフォルトのメッセージを設定する。
 from http://chaichan.lolipop.jp/qa4000/qa4478.htm
   https://www.nczonline.net/blog/2009/03/03/the-art-of-throwing-javascript-errors/
   https://www.joyent.com/developers/node/design/errors
   http://stackoverflow.com/questions/31089801/extending-error-in-javascript-with-es6-syntax
###
class BaseError extends Error
  constructor: (@message) ->
    super @message
    @name = @constructor.name
    Error.captureStackTrace(@, @name);

class ArgumentError extends BaseError
  constructor: (@message) ->
    super @message

class ExecuteError extends BaseError
  constructor: (@message) ->
    super @message

class IOError extends BaseError
  constructor: (@message) ->
    super @message

class FileNotFoundError extends IOError
  constructor: (@message) ->
    super @message


class Settings
  constructor: (@c_path) ->
    c_path = @c_path
    @config = {
      "port": 8080,
      "root": process.env.HOME,
    }
    fs.access c_path, fs.R_OK | fs.W_OK, (err) ->
      throw FileNotFoundError if err?
      fs.readFile c_path, 'utf8', (err, data) ->
        throw new IOError if err?
        json = JSON.parse data
        @config = _.extendOwn(@config, json)

  getConfig: (key)->
    val = @config[key]
    console.log(val)
    val

  setConfig: (key, val)->
    @config[key] = val
    return @

  save: ->
    json = JSON.stringify(@config, null, '    ')
    fs.writeFile(@c_path, json)
    return @

# ---
# generated by js2coffee 2.1.0

settings = new Settings(app_conf_file)

# from http://qiita.com/ktty1220/items/c89a0101ab4a87311637
# from http://stackoverflow.com/questions/11386492/accessing-line-number-in-v8-javascript-chrome-node-js
# Object.defineProperty(global, '__stack', {
#   get: ->
#     orig = Error.prepareStackTrace;
#     Error.prepareStackTrace = (_, stack)->stack
#     err = new Error;
#     Error.captureStackTrace(err, arguments.callee);
#     stack = err.stack;
#     Error.prepareStackTrace = orig;
#     stack;
# });
# Object.defineProperty(global, '__line', {
#   get: ->
#     __stack[1].getLineNumber();
# });

console_scroll_top = ->
  $psconsole = $("#console");
  $psconsole.scrollTop($psconsole[0].scrollHeight - $psconsole.height())

logger = {
  _execute: (meg, level) ->
    dt = new Date();
    formated_date = logger._dateFormat(dt)
    switch level
      when "debug"
        console.log("#{formated_date} #{meg}")
        $console_html = $("<div class=\"line\">#{formated_date} <span class=\"gray\">#{meg}</span></div>")
      when "success"
        console.log("#{formated_date} %c#{meg}%c", 'color: green;', '')
        $console_html = $("<div class=\"line\">#{formated_date} <span class=\"green\">#{meg}</span></div>")
      when "info"
        console.log("#{formated_date} %c#{meg}%c", 'color: #00bcd4;', '')
        $console_html = $("<div class=\"line\">#{formated_date} <span class=\"skyblue\">#{meg}</span></div>")
      when "warn"
        console.log("#{formated_date} %c#{meg}%c", 'color: #ffd700;', '')
        $console_html = $("<div class=\"line\">#{formated_date} <span class=\"yellow\">#{meg}</span></div>")
      when "fatal"
        console.error("#{formated_date} %c#{meg}%c", 'color: red;', '')
        $console_html = $("<div class=\"line\">#{formated_date} <span class=\"red\">#{meg}</span></div>")
    $("#console_panel").append($console_html)
    console_scroll_top()

  _dateFormat: do ->
    months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    return (date)->
      yy  = date.getFullYear().toString().slice(-2)
      m  = date.getMonth()
      dd  = date.getDate()
      HH = date.getHours()
      mm = date.getMinutes()
      ss = date.getSeconds()
      "[#{yy} #{months[m]} #{dd} #{HH}:#{mm}:#{ss}]"

  debug: (meg) ->
    logger._execute meg, "debug"
  success: (meg) ->
    logger._execute meg, "success"
  info: (meg) ->
    logger._execute meg, "info"
  warn: (meg) ->
    logger._execute meg, "warn"
  fatal: (meg) ->
    logger._execute meg, "fatal"
}
log = logger.debug # alias

# from http://www.yoheim.net/blog.php?q=20121014
printStackTrace = (e) ->
  if e.stack?
    # 出力方法は、使いやすいように修正する。
    logger.fatal(e.stack)
  else
    # stackがない場合にsは、そのままエラー情報を出す。
    logger.fatal(e.message, e)

###---------------------------
  Error handling
  from http://www.yoheim.net/blog.php?q=20131102
-----------------------------###
process.on 'uncaughtException', (e) ->
  printStackTrace(e)


###---------------------------
  commands
-----------------------------###
# settings
pathToNginx   = which.sync('nginx')
pathToPhpfpm  = which.sync('php56-fpm')
pathToMysql   = which.sync('mysql.server')

class nginx
  constructor: (@path, @port, @pid)->
  set_path: (@path)->
  set_port: (@port)->
  set_pid:  (@pid)->
  start: ()->
    d = new $.Deferred
    command = "#{pathToNginx} -p `pwd` -c #{path.join(nginx_conf_dir, 'nginx.conf')}"
    exec command, (err, stdout, stderr) ->
      $nginx_status = $("#nginx_status img")
      if err?
        $nginx_status.attr("src", "./images/icon_red.png") if $nginx_status?
        throw new ExecuteError
      $nginx_status.attr("src", "./images/icon_green.png") if $nginx_status?
      logger.success('nginx start!')
      d.resolve()
    d.promise()
  stop: ()->
    d = new $.Deferred
    exec "#{pathToNginx} -s stop", (err, stdout, stderr) ->
      $nginx_status = $("#nginx_status img")
      if err?
        $nginx_status.attr("src", "./images/icon_red.png") if $nginx_status?
        throw new ExecuteError
      $nginx_status.attr("src", "./images/icon_empty.png") if $nginx_status?
      logger.success('server stoped!')
      d.resolve()
    d.promise()

class phpfpm
  constructor: (@path, @port, @pid)->
  set_path: (@path)->
  set_port: (@port)->
  set_pid:  (@pid)->
  start: ()->
    d = new $.Deferred;
    exec "#{pathToPhpfpm} start", (err, stdout, stderr) ->
      $phpfpm_status = $("#php-fpm_status img")
      if err?
        $phpfpm_status.attr("src", "./images/icon_red.png") if $phpfpm_status?
        throw new ExecuteError
      $phpfpm_status.attr("src", "./images/icon_green.png") if $phpfpm_status?
      logger.success('php56-fpm start!')
      d.resolve()
    d.promise()
  stop: ()->
    d = new $.Deferred
    exec "#{pathToPhpfpm} stop", (err, stdout, stderr) ->
      $phpfpm_status = $("#php-fpm_status img")
      if err?
        $phpfpm_status.attr("src", "./images/icon_red.png") if $phpfpm_status?
        throw new ExecuteError
      $phpfpm_status.attr("src", "./images/icon_empty.png") if $phpfpm_status?
      logger.success('php56-fpm stoped!')
      d.resolve()
    d.promise()

class mysql
  constructor: (@path, @port, @pid)->
  set_path: (@path)->
  set_port: (@port)->
  set_pid:  (@pid)->
  start: ()->
    d = new $.Deferred;
    exec "#{pathToMysql} start", (err, stdout, stderr) ->
      $mysql_status = $("#mysql_status img")
      if err?
        $mysql_status.attr("src", "./images/icon_red.png") if $mysql_status?
        throw new ExecuteError
      $mysql_status.attr("src", "./images/icon_green.png") if $mysql_status?
      logger.success('mysql start!')
      d.resolve()
    d.promise()
  stop: ()->
    d = new $.Deferred;
    exec "#{pathToMysql} stop", (err, stdout, stderr) ->
      $mysql_status = $("#mysql_status img")
      if err?
        $mysql_status.attr("src", "./images/icon_red.png") if $mysql_status?
        throw new ExecuteError
      $mysql_status.attr("src", "./images/icon_empty.png") if $mysql_status?
      logger.success('mysql stop!')
      d.resolve()
    d.promise()


# settingsファイルがあれば、それを読み込み、なければデフォルトで作成
do ->
  # fs.copy template_dir, conf_path, (err) ->
  #   if err
  #     return console.error(err)
  #   console.log 'success!'
  #   return

  root = settings.getConfig("root")
  port = settings.getConfig("port")

  $('input[name="root"]').val(root);
  $('input[name="port"]').val(port);


###---------------------------
  bind
-----------------------------###

do ->
  inc_nginx = new nginx()
  inc_phpf  = new phpfpm()
  inc_mysql = new mysql()

  window.ngx_start   = inc_nginx.start
  window.ngx_stop    = inc_nginx.stop
  window.phpf_start  = inc_phpf.start
  window.phpf_stop   = inc_phpf.stop
  window.mysql_start = inc_mysql.start
  window.mysql_stop  = inc_mysql.stop

  server_started = false
  $("#nginx_btn").on "click", ->
    $this = $(this)
    if server_started
      # server stop tasks
      $this.addClass("avoid-clicks").addClass("active")
      $.when(inc_nginx.stop(), inc_phpf.stop(), inc_mysql.stop()).then ->
        $this.removeClass("btn-danger")
          .addClass("btn-primary")
          .text("Server Start")
          .removeClass("avoid-clicks")
          .removeClass("active")
    else
      # server start tasks
      $this.addClass("avoid-clicks").addClass("active")
      $.when(inc_nginx.start(), inc_phpf.start(), inc_mysql.start()).then ->
        $this.removeClass("btn-primary")
          .addClass("btn-danger")
          .text("Server Stop")
          .removeClass("avoid-clicks")
          .removeClass("active")

    server_started = !server_started

"none"
