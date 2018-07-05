sudo pip3 freeze --local | grep -v '^\-e' | cut -d = -f 1  | sudo xargs -n1 pip3 install -U

