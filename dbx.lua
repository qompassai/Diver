-- ~/.config/nvim/dbx.lua
-------------------------
return {
  {
    name = "MySQL Local",
    url = "mysql://root:password@localhost:3306/"
  },
  {
    name = "MySQL Production",
    url = "mysql://user:password@production-server:3306/database"
  }
}

  {
    name = "SQLite Main",
    url = "sqlite:~/databases/main.sqlite"
  },
  {
    name = "Project DB",
    url = "sqlite:./db/development.sqlite3"
  }
}
  {
    name = "PostgreSQL Local",
    url = "postgresql://postgres:password@localhost:5432/postgres"
  },
  {
    name = "PostgreSQL Production",
    url = "postgresql://user:password@production-server:5432/database"
  }
}
