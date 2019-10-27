# len(set(a) & set(b))
# x = {1: 2, 3: 4, 4: 3, 2: 1, 0: 0}
# sorted_x = sorted(x.items(), key=lambda kv: kv[1])
import sys

from flask import Flask, render_template, request
import pyximport; pyximport.install()
import requests
from concurrent.futures import ThreadPoolExecutor, Future
from operator import itemgetter

app = Flask("Steam")
API_KEY = "2C38F4C00E5E03B70D86FD3DDF7E7886"


@app.route('/')
def home():
    return render_template('home.html')


@app.route('/user')
def hello():
    try:
        name = request.args.get('name', default='', type=str)

        api_key = API_KEY
        top20 = []
        try:
            steam_id = int(name)
            top20 = get_top_20(steam_id)
        except ValueError:  # Not an ID, but a vanity URL.\
            json = requests.get(
                "https://api.steampowered.com/ISteamUser/ResolveVanityURL/v1/?key=%(api_key)s&vanityurl=%(name)s" % locals()).json()  # To execute get request
            if json["response"]["success"]:
                steam_id = json["response"]["steamid"]
                # url = "http://api.steampowered.com/ISteamUser/GetPlayerSummaries/v0002/?key=2C38F4C00E5E03B70D86FD3DDF7E7886&steamids=" + str(steam_id)
                # response = requests.get(url)
                # json["response"]["players"][0]
                top20 = get_top_20(steam_id)
            else:
                print("vanity url not found")
        # content = "Your real name is {0}. You have {1} friends and {2} games.".format(steam_user.real_name,
        #                                                                              len(steam_user.friends),
        #                                                                              len(steam_user.games))
        # img = steam_user.avatar
        return render_template('hello.html', name=name, top=top20)
    except Exception as ex:
        # We might not have permission to the user's friends list or games, so just carry on with a blank message.
        return render_template('hello.html', name=name)


# def getSameFriends(friend_id, friends_id):
#     api_key = API_KEY
#     json2 = requests.get(
#         "http://api.steampowered.com/ISteamUser/GetFriendList/v0001/?key=%(api_key)s&steamid=%(friend_id)s" % locals()).json()
#     friendListExists = "friendslist" in json2
#     if friendListExists and ("friends" in json2["friendslist"]):
#         friends_of_friend = json2["friendslist"]["friends"]
#         friends_of_friend_id = [friend["steamid"] for friend in friends_of_friend]
#         same_friend_count = len(set(friends_id) & set(friends_of_friend_id))
#     else:
#         same_friend_count = 0
#     return same_friend_count


def add_same_friends(friend_id, friends_id, same_friends):
    api_key = API_KEY
    json = requests.get(
        "http://api.steampowered.com/ISteamUser/GetFriendList/v0001/?key=%(api_key)s&steamid=%(friend_id)s" % locals()).json()
    friend_list_exists = "friendslist" in json
    if friend_list_exists and ("friends" in json["friendslist"]):
        friends_of_friend = json["friendslist"]["friends"]
        friends_of_friend_id = [friend["steamid"] for friend in friends_of_friend]
        same_friend_count = len(set(friends_id) & set(friends_of_friend_id))
    else:
        same_friend_count = 0
    same_friends[friend_id] = same_friend_count

def add_player_info(steam_id, same_friend_count, players_info):
    api_key = API_KEY
    json = requests.get(
        "http://api.steampowered.com/ISteamUser/GetPlayerSummaries/v0002/?key=%(api_key)s&steamids=%(steam_id)s" % locals()).json()
    response_exists = "response" in json
    if response_exists and ("players" in json["response"]) and len(json["response"]["players"]):
        player = json["response"]["players"][0]
        players_info.append([player["personaname"], player["profileurl"], player["avatar"], same_friend_count])

def get_top_20(steam_id):
    api_key=API_KEY
    json = requests.get(
        "http://api.steampowered.com/ISteamUser/GetFriendList/v0001/?key=%(api_key)s&steamid=%(steam_id)s" % locals()).json()
    friends = json["friendslist"]["friends"]
    friends_id = [friend["steamid"] for friend in friends]
    same_friends = {}
    with ThreadPoolExecutor(max_workers=100) as executor:
        for friend_id in friends_id:
            future = executor.submit(add_same_friends, friend_id, friends_id, same_friends)
    sorted_same_friends = sorted(same_friends.items(), key=lambda kv: kv[1], reverse=True)
    top20 = sorted_same_friends[:20]
    players_info = []
    with ThreadPoolExecutor(max_workers=100) as executor:
        for top in top20:
            future = executor.submit(add_player_info, top[0], top[1], players_info)
    top20_player_info = sorted(players_info, key=itemgetter(3), reverse=True)
    return top20_player_info

if __name__ == '__main__':
    app.run()
