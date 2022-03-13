FROM python:3.10.2-bullseye
# Install dependency/virtual-environment-management tool
RUN /usr/local/bin/python3 -m pip install --upgrade pip
# RUN pip install poetry
RUN curl -sSL https://raw.githubusercontent.com/python-poetry/poetry/master/get-poetry.py | python -
RUN poetry config virtualenvs.create true
RUN poetry config virtualenvs.in-project true
