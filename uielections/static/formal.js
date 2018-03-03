var Formal = (function($){
    var that = {};
    
    that.initAll = function() {
        var $forms = $("form.formal");
        that._initData($forms);
        that._initCkEditor($forms);
        that._events($forms);
    };

    that.init = function(form) {
        var $form = $(form);
        that._initData($form);
        that._initCkEditor($form);
        that._events($form);
    };

    that._initData = function($forms) {
        $forms.each(function(i, el) {
            var $form = $(el);
            var $$formal = $form.data("formal");
            if ($$formal) {
                return;
            }

            $$formal = {};
            if ($form.hasClass("simple")) {
                $$formal.errors = true;
                $$formal.alerts = true;
                $$formal.redirects = true;
            } else {
                $$formal.errors = false;
                $$formal.alerts = false;
                $$formal.redirects = false;
            }

            if ($form.data("formal-alerts")) {
                $$formal.alerts = true;
            }

            if ($form.data("formal-errors")) {
                $$formal.errors = true;
            }

            if ($form.data("formal-redirects")) {
                $$formal.redirects = true;
            }

            $$formal.success = $form.data("formal-success");
            $$formal.error = $form.data("formal-error");
            $$formal.submit = $form.data("formal-submit");

            $form.data("formal", $$formal);
        });
    };

    that.ckeditor = function(el) {
        var options = {};
        // can also config using the data-cke-* HTML attributes
        if ($(el).data("ckeditor-use-paragraph") != "1") {
            options.enterMode = CKEDITOR.ENTER_BR;
            options.autoParagraph = false;
        }
        options.ignoreEmptyParagraph = true;
        $.when( $(el).ckeditor(options).promise ).then( function() {
            // Now all editors have already been created.
        });
    };

    that._initCkEditor = function($form) {
        var $editors = $form.find("textarea[data-use-ckeditor]:not(.templated)");
        $editors.each(function(i, el) {
            that.ckeditor(el);
        });
    };
    
    that.objectToString = function(errormsg, prefix) {
        
        $.each(errormsg, function(fieldname, msg) {
            var newmsg = [];
            if (msg instanceof Array && msg.length > 0 && !(typeof msg[0] === 'string' || msg[0] instanceof String)) {
                // an array of non-strings
                for (var i = 0; i<msg.length; i++) {
                    for (var subfieldname in msg[i]) {
                        newmsg.push("Item " + i + " - " + subfieldname + ": " + msg[i][subfieldname]);
                    }
                }
            } else if (msg instanceof Array && msg.length > 0) {
                newmsg = msg;
            }
            errormsg[fieldname] = newmsg;
        });
        
        return errormsg;
    };

    that._events = function($forms) {
        $forms.submit(function(e) {
            e.preventDefault();

            var $form = $(e.target);
            var $$formal = $form.data("formal");
            if ($$formal.alerts) {
                that.clearAlert($form);
            }
            
            if ($$formal.submit && !$$formal.submit($form, e)) {
                return false;
            }
            
            $.ajax({
                url: $form.attr("action"),
                method: $form.attr("method"),
                data: $form.serialize(),
                dataType: "json",
            }).done(function(data, textStatus, jqXHR) {
                // Check if the call was successful or not
                if (data.success) {
                    if ($$formal.alerts) {
                        that.prependAlert($form, data.message, data.message_severity || "success");
                    }
                    if ($$formal.errors) {
                        $form.find("small.help-block.error").remove();
                        $form.find("div.has-error").removeClass("error");
                    }
                    if ($$formal.success) {
                        $$formal.success($form, data);
                    }
                } else if ($$formal.errors && data.errors) {
                    if ($$formal.alerts) {
                        that.prependAlert($form, data.message, data.message_severity || "warning");
                    }
                    if ($$formal.errors) {
                        var errormsg = $.extend({}, data.errors);
                        errormsg = that.objectToString(errormsg);
                        console.log("Errors:", errormsg);
                        var handled = [];
                        $form.find("input,select,textarea,ol,table,.form-group").each(function (i, el) {
                            var $f = $(el);
                            var k = $f.attr("name");
                            if (!k) {
                                return;
                            }
                            var $p;
                            if ($f.hasClass("form-group")) {
                                $p = $f.children(".error-container");
                            } else {
                                $p = $f.parent();
                            }
                            $p.find("small.help-block.error").remove();
                            if (!errormsg[k]) {
                                $p.removeClass("has-error");
                            } else {
                                $p.addClass("has-error");
                                for (var i = 0; i<errormsg[k].length; i++) {
                                    $p.append($('<small class="help-block error">').text(errormsg[k][i]));
                                }
                            }
                            if ($p) {
                                handled.push(k);
                            }
                        });
                        var outstanding = '';
                        $.each(errormsg, function(fieldname, msg) {
                            if (handled.indexOf(fieldname) < 0) {
                                outstanding += fieldname + ":\n";
                                for (var i = 0; i<msg.length; i++) {
                                    outstanding += msg[i] + "\n";
                                }
                            }
                        });
                        console.log(outstanding);
                        if (outstanding) {
                            that.prependAlert($form, outstanding, data.message_severity || "warning");
                        }
                    }
                    if ($$formal.error) {
                        $$formal.error($form, data);
                    }
                } else {
                    if ($$formal.alerts) {
                        that.prependAlert($form, data.message, data.message_severity || "error");
                    }
                    if ($$formal.error) {
                        $$formal.error($form, data);
                    }
                }

                // Check if there's a redirect bel da2
                if ($$formal.redirects && data.redirect) {
                    setTimeout(function() {
                        window.location = data.redirect;
                    }, 1000);
                    return;
                } else if ($$formal.redirects && data.refresh) {
                    setTimeout(function() {
                        window.location.reload();
                    }, 1000);
                }
            }).fail(function(jqXHR, textStatus, errorThrown) {
                console.error("fail", jqXHR.responseJSON);
                if ($$formal.alerts && jqXHR.responseJSON) {
                    that.prependAlert($form, jqXHR.responseJSON.message,
                        "error");
                } else if ($$formal.alerts) {
                    that.prependAlert($form, textStatus, "error");
                }
                if ($$formal.error) {
                    $$formal.error($form, jqXHR.responseJSON,
                        jqXHR, textStatus, errorThrown);
                }
            });

            return false;
        });
    };

    that.legalMessageSeverity = {
        'info': 'alert-info', 'success': 'alert-success',
        'warning': 'alert-warning', 'error': 'alert-error'
    };
    that.defaultMessageSeverity = 'info';

    that.prependAlert = function($parent, message, severity) {
        if (!message) {
            return;
        }
        if (!severity) {
            severity = that.defaultMessageSeverity;
        }
        var severityClass = that.legalMessageSeverity[severity];
        if (!severityClass) {
            severity = that.defaultMessageSeverity;
            severityClass = that.legalMessageSeverity[severity];
        }
        // TODO: Make alerts closeable and/or timeout
        var $message = $('<div class="alert" role="alert"><span></span></div>');
        $message.children("span").text(message);
        $message.addClass(severityClass);
        $message.hide().slideDown("slow");
        $parent.prepend($message);
        return $message;
    };

    that.clearAlert = function($parent) {
        $parent.children(".alert").slideUp("slow", function() {
            $(this).remove();
        });
    };

    return that;
})(jQuery);
