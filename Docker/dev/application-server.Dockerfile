FROM python:3.10.2-slim
RUN /usr/local/bin/python3 -m pip install --upgrade pip
RUN useradd -ms /bin/bash -u 1001 applicationserver
# RUN usermod -a -G wheel applicationserver
USER applicationserver
WORKDIR /home/applicationserver   
ENV PATH=/home/applicationserver/.local/bin/:$PATH
# RUN pip install poetry
# RUN apt-get install curl
# RUN curl -sSL https://raw.githubusercontent.com/python-poetry/poetry/master/get-poetry.py | python -
# RUN /bin/bash -c "source $HOME/.poetry/env"
# RUN poetry config virtualenvs.create true
# RUN poetry config virtualenvs.in-project true
