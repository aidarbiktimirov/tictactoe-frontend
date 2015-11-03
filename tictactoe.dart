import 'dart:html';
import 'dart:async';
import 'dart:convert';

class ApiClient {
    ApiClient() {
    }

    void listGames(callback) {
        HttpRequest.getString('/api/games/list/')
            .then((String response) => callback(JSON.decode(response)));
    }

    void loadGame(id, x, y, w, h, callback) {
        HttpRequest.getString('/api/games/show/?id=${id}&x=${y}&y=${x}&width=${h}&height=${w}')
            .then((String response) => callback(JSON.decode(response)));
    }

    void updateGame(id, x, y, user, callback) {
        HttpRequest.getString('/api/games/update/?id=${id}&x=${x}&y=${y}&username=${user}')
            .then((String response) => callback(JSON.decode(response)))
            .catchError((error) => window.alert(error.target.responseText));
    }

}

class App {
    var gameList;
    var username;
    var field;
    var fieldControls;
    var newGameBtn;
    var api;
    var lastKnownGameId;
    var busy;
    var currentGame;
    var x;
    var y;

    static final controlDeltas = [[0, -5], [5, 0], [0, 5], [-5, 0]];
    static const fieldWidth = 30;
    static const fieldHeight = 20;

    App(this.gameList, this.username, this.field, this.fieldControls, this.newGameBtn) {
        api = new ApiClient();
        lastKnownGameId = -1;
        busy = false;
        currentGame = -1;
        x = 0;
        y = 0;
        for (var i = 0; i < fieldControls.length; ++i) {
            var control = fieldControls[i];
            control.disabled = true;
            control.onClick.listen((event) => moveField(controlDeltas[i]));
        }
    }

    void run() {
        listGames();
    }

    void makeBusy() {
        // TODO: some kind of mutex is required
        if (busy) {
            window.alert('Not so fast!');
        }
        busy = true;
    }

    void listGames() {
        if (busy) {
            new Timer(const Duration(seconds: 5), listGames);
            return;
        }
        makeBusy();
        api.listGames((var games) {
            if (games.length == 0) {
                gameList.innertHtml = '<li class="disabled"><a href="#">No games found</a></li>';
            } else {
                if (lastKnownGameId == -1) {
                    gameList.children.clear();
                }
                int newLastKnownGameId = lastKnownGameId;
                for (var game in games) {
                    if (lastKnownGameId >= game["id"]) {
                        continue;
                    }
                    if (game["id"] > newLastKnownGameId) {
                        newLastKnownGameId = game["id"];
                    }
                    var element = new LIElement();
                    var message = '<b>${game["users"][0]}</b> vs <b>${game["users"][1]}</b>';
                    if (game.containsKey("winner")) {
                        var tag1 = game["winner"] == 'x' ? "b" : "s";
                        var tag2 = game["winner"] == 'o' ? "b" : "s";
                        message = '<${tag1}>${game["users"][0]}</${tag1}> vs <${tag2}>${game["users"][1]}</${tag2}>';
                    }
                    element.children.add(new AnchorElement()
                        ..href = '#'
                        ..innerHtml = message);
                    element.children[0].onClick.listen((event) {
                        x = 0;
                        y = 0;
                        loadGame(game["id"]);
                    });
                    gameList.children.insert(0, element);
                }
                lastKnownGameId = newLastKnownGameId;
            }
            busy = false;
            new Timer(const Duration(seconds: 5), listGames);
        });
    }

    void loadGame(var id) {
        if (busy) {
            return;
        }
        print('${x} ${y}');
        makeBusy();
        api.loadGame(id, x, y, fieldWidth, fieldHeight, (var gameField) {
            for (var control in fieldControls) {
                control.disabled = false;
            }

            currentGame = id;
            field.children.clear();
            for (var i = 0; i < gameField.length; ++i) {
                var row = gameField[i];
                var rowElement = new TableRowElement();
                for (var j = 0; j < row.length; ++j) {
                    var cell = row[j];
                    var cellElement = new TableCellElement();
                    if (cell == null) {
                        var btn = new ButtonElement();
                        btn.onClick.listen((event) => updateGame(id, x + i, y + j, username.value));
                        cellElement.children.add(btn);
                    } else {
                        cellElement.text = cell;
                    }
                    rowElement.children.add(cellElement);
                }
                field.children.add(rowElement);
            }
            busy = false;
        });
    }

    void updateGame(id, x, y, user) {
        print(user);
        api.updateGame(id, x, y, user, (var response) {
            print(response);
            loadGame(currentGame);
        });
    }

    void newGame() {
        content.children.clear();
    }

    void moveField(var delta) {
        if (currentGame == -1) {
            window.alert('No game is loaded');
            return;
        }
        x += delta[0];
        y += delta[1];
        loadGame(currentGame);
    }
}

main() {
    var gameList = querySelector('#game_list');
    var username = querySelector('#username');
    var field = querySelector('#field');
    var fieldControls = [querySelector('#move_up'), querySelector('#move_right'), querySelector('#move_down'), querySelector('#move_left')];
    var newGameBtn = querySelector('#new_game');
    var app = new App(gameList, username, field, fieldControls, newGameBtn);
    app.run();
}
