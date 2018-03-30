$(document).ready(function() {
    var STORAGE_KEY_OPEN = "simulations";

    function makeTab(simulation) {
        var $li = $('<li role="presentation" class="simulation"></li>');
        var $a = $('<a href="" aria-controls="" role="tab" data-toggle="tab"></a>');
        $a.attr("href", "#tab-pane-" + simulation);
        $a.attr("aria-controls", "tab-pane-" + simulation);
        $a.text("Sim #" + simulation);
        $li.data("simulation", simulation);
        $li.attr("id", "tab-" + simulation);
        $li.append($a);
        $a.append('<a class="remove-simulation-btn btn btn-xs" style="margin-left: 1em;">&cross;</a>');
        return $li;
    }

    function makePane(simulation) {
        var $div = $('<div role="tabpanel" class="tab-pane simulation" id=""></div>');
        var $iframe = $('<iframe class="simulation" name="" id="" src="about:blank" frameborder="0" width="100%" scrolling="yes"></iframe>');
        $iframe.attr("name", "iframe_simulation_" + simulation);
        $iframe.attr("id", "iframe_simulation_" + simulation);
        $iframe.data("loaded", false);
        $iframe.data("loading", false);
        $div.attr("id", "tab-pane-" + simulation);
        $div.data("simulation", simulation);
        $div.append($iframe);
        return $div;
    }

    function loadSimulations($tabs, $panes) {
        var simulationsJson = localStorage.getItem(STORAGE_KEY_OPEN);
        var simulations = simulationsJson? JSON.parse(simulationsJson) : [];
        $.each(simulations, function(i, simulation) {
            $tabs.append(makeTab(simulation));
            $panes.append(makePane(simulation));
        });
    }

    function addSimulation(simulation, $tabs, $panes) {
        console.log("Adding", simulation);
        var simulationsJson = localStorage.getItem(STORAGE_KEY_OPEN);
        var simulations = simulationsJson? JSON.parse(simulationsJson) : [];
        if (simulations.indexOf(simulation) < 0) {
            simulations.push(simulation);
            $tabs.append(makeTab(simulation));
            $panes.append(makePane(simulation));
        }
        localStorage.setItem(STORAGE_KEY_OPEN, JSON.stringify(simulations));
    }

    function removeSimulation(simulation, $tabs, $panes) {
        console.log("Removing", simulation);
        var simulationsJson = localStorage.getItem(STORAGE_KEY_OPEN);
        var simulations = simulationsJson? JSON.parse(simulationsJson) : [];
        var index = simulations.indexOf(simulation);
        if (index >= 0) {
            simulations.splice(index, 1);
            $tabs.children("li[id=tab-" + simulation + "]").remove();
            $panes.children("div[id=tab-pane-" + simulation + "]").remove();
        }
        localStorage.setItem(STORAGE_KEY_OPEN, JSON.stringify(simulations));
    }

    function goToSimulation(simulation, $tabs, $panes) {
        $tabs.find('li[id=tab-' + simulation + ']').tab('show');
    }

    $("#simulation-tabs").on("click", ".remove-simulation-btn", function (ev) {
        ev.preventDefault();

        var simulation = $(this).parents("li").data("simulation");
        removeSimulation(simulation, $("#simulation-tabs"), $("#simulation-panes"));

        $('#simulation-tabs a[data-toggle="tab"]:first').tab('show');
        return false;
    }).on('show.bs.tab', 'a[data-toggle="tab"]', function (e) {
        var $oldTab = $(e.relatedTarget);
        var $tab = $(e.target);
        var $pane = $($tab.attr("href"));
        var $iframe = $pane.find("iframe.simulation");
        var simulation = $pane.data("simulation");
        console.log("Showing", simulation);
        if (!simulation || $iframe.data("loaded") || $iframe.data("loading")) {
            return;
        }
        $pane.addClass("loading");
        $iframe.data("loading", true);
        $iframe.on("load error", function() {
            $iframe.data("loaded", true);
            $iframe.data("loading", false);
            $pane.removeClass("loading");
            resizeIframes();
        });
        $iframe.attr("src", "/simulation/" + simulation + "/");
    });

    function resizeIframes() {
        // See https://stackoverflow.com/a/20125592
        $('iframe.simulation').height(function(){
            return $(window).height()-$(this).offset().top;
        });
    }
    $(window).on('load resize', function(){
        resizeIframes();
    });

    $("form.formal#simulation-create-form").data("formal-success", function ($form, response) {
        addSimulation(response.data.name, $("#simulation-tabs"), $("#simulation-panes"));
    });
    Formal.initAll();

    loadSimulations($("#simulation-tabs"), $("#simulation-panes"));
});
