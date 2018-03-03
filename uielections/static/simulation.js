var RENDER_MAP = {
    'datetime': function(data, type, row) {
        if (!data) {
            return data;
        }
        var dt = moment(data);
        return $('<div>').append($("<span/>").attr("title", dt.format()).text(dt.fromNow())).html();
    },
    'boolean': function(data, type, row) {
        if (data === true) {
            return '<span class="glyphicon glyphicon-check" aria-hidden="true"></span>';
        } else if (data === false) {
            return '<span class="glyphicon glyphicon-unchecked" aria-hidden="true"></span>';
        } else {
            return data;
        }
    },
};
function renderTable(tbl, metadata_url, table_id) {
    $.get(metadata_url).success(function(response) {
        var options = $.extend({}, response.datatables);
        options.columns = $(options.columns).map(function(i, col) {
            var ftype = col._type;
            delete col._type;
            var index = ftype.length;
            while (index >= 0) {
                var render = RENDER_MAP[ftype];
                if (render) {
                    col.render = render;
                    break;
                }
                ftype = ftype.substring(0, index);
                index = ftype.lastIndexOf(':');
            }
            return col;
        });
        var table = $(tbl).DataTable(options);
        $(tbl).data("create_ajax", response.create.ajax);
        $(tbl).data("fields", response.create.fields);
    });
}
$(document).ready(function() {
    var dependencyMap = {};
    for (var tableId in TABLES) {
        var tableUrl = TABLES[tableId];
        var tbl = $('#table-' + tableId);
        var ancestors = ($(tbl).data("dependson") || "").split(" ");
        $.each(ancestors, function (i, el) {
            var descendants = dependencyMap[el] || [];
            descendants.push(tableId);
            dependencyMap[el] = descendants;
        });
        tbl.data("table-id", tableId);
        renderTable(tbl, tableUrl, tableId);
    }
    for (var tableId in TABLES) {
        var tbl = $('#table-' + tableId);
        $(tbl).data("descendants", dependencyMap[tableId] || []);
    }
    $(".table-container").on("click", "table tr", function(ev) {
        ev.preventDefault();
        var $form = $("#edit-modal form.formal#edit_form");
        var $deleteForm = $("#edit-modal form.formal#delete_form");
        var $table = $(this).parents("table");

        if ($table.data('editable') === false) {
            return false;
        }

        var table = $table.DataTable();
        var data = table.row(this).data(); // .DT_RowData.fields_data;
        var fieldsData = data.DT_RowData.fields_data;

        $form.html("");
        $form.attr("method", "POST");
        $form.attr("action", data.DT_RowData.edit_ajax);
        $form.data("table", table);
        $form.data("table-id", $table.data("table-id"));
        $.each($table.data("fields"), function(i, el) {
            var $field;
            if (el.choices) {
                $field = $('<select name="">');
                $.each(el.choices, function(j, op) {
                    $field.append($('<option>').attr("value", op.id).text(op.name));
                });
                $field.prop('disabled', !el.visible || !el.editable);
            } else {
                $field = $('<input type="text" value="" name="">');
            }
            $field.attr("name", el.name);
            $field.attr("id", "field-" + el.name);
            $field.prop("readonly", !el.visible || !el.editable);
            $field.val(fieldsData[el.name]);
            var $div = $('<div class="form-group"></div>');
            $div.append($("<label>").attr("for", "field-" + el.name).text(el.title));
            $div.append($field);
            $form.append($div);
        });

        $deleteForm.html("");
        $deleteForm.attr("method", "POST");
        $deleteForm.attr("action", data.DT_RowData.delete_ajax);
        $deleteForm.data("table", table);
        $deleteForm.data("table-id", $table.data("table-id"));
        $("#edit-modal").modal();
        return false;
    }).on('click', '.add-btn', function (ev) {
        ev.preventDefault();
        var $form = $("#edit-modal form.formal#edit_form");
        var $table = $(this).parents(".table-container").find("table");
        var table = $table.DataTable();

        $form.html("");
        $form.attr("method", "POST");
        $form.attr("action", $table.data("create_ajax"));
        $form.data("table", table);
        $form.data("table-id", $table.data("table-id"));
        $.each($table.data("fields"), function(i, el) {
            var $field;
            if (el.choices) {
                $field = $('<select name="">');
                $.each(el.choices, function(j, op) {
                    $field.append($('<option>').attr("value", op.id).text(op.name));
                });
            } else {
                $field = $('<input type="text" value="" name="">');
            }
            $field.attr("name", el.name);
            $field.attr("id", "field-" + el.name);
            $field.prop("readonly", !el.visible);
            var $div = $('<div class="form-group"></div>');
            $div.append($("<label>").attr("for", "field-" + el.name).text(el.title));
            $div.append($field);
            $form.append($div);
        });
        $("#edit-modal").modal();

        return false;
    });
    $("#edit-modal form.formal#edit_form").data("formal-success", function () {
        console.log("success");
        $("#edit-modal").modal('hide');
        var table = $("#edit-modal form.formal#edit_form").data("table");
        var tableId = $("#edit-modal form.formal#edit_form").data("table-id");
        table.ajax.reload(null, false);
        var descendants = $("table#table-" + tableId).data("descendants");
        $.each(descendants, function(i, el) {
            var elTable = $("table#table-" + el).DataTable();
            elTable.ajax.reload(null, false);
        });
    });
    $("#edit-modal form.formal#delete_form").data("formal-success", function () {
        console.log("success");
        $("#edit-modal").modal('hide');
        var table = $("#edit-modal form.formal#delete_form").data("table");
        var tableId = $("#edit-modal form.formal#edit_form").data("table-id");
        table.ajax.reload(null, false);
        var descendants = $("table#table-" + tableId).data("descendants");
        $.each(descendants, function(i, el) {
            var elTable = $("table#table-" + el).DataTable();
            elTable.ajax.reload(null, false);
        });
    });
    Formal.initAll();
} );