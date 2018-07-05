sudo pip2 freeze --local | grep -v '^\-e' | cut -d = -f 1  | sudo xargs -n1 pip2 install -U

