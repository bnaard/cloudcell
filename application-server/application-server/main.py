from typing import Optional
from fastapi import FastAPI
from sqlmodel import Field, Session, SQLModel, create_engine, select


class Test(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    teststr: str = Field(index=True)
    testint: Optional[int] = Field(default=None, index=True)


sqlite_file_name = "database.db"
sqlite_url = f"sqlite:///{sqlite_file_name}"

connect_args = {"check_same_thread": False}
engine = create_engine(sqlite_url, echo=True, connect_args=connect_args)


def create_db_and_tables():
    SQLModel.metadata.create_all(engine)


app = FastAPI()


@app.on_event("startup")
def on_startup():
    create_db_and_tables()


@app.post("/test/")
def create_test(test: Test):
    with Session(engine) as session:
        session.add(test)
        session.commit()
        session.refresh(test)
        return test


@app.get("/tests/")
def read_tests():
    with Session(engine) as session:
        tests = session.exec(select(Test)).all()
        return tests
