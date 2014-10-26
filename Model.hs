module Model where

import Yesod
import Data.Text (Text)
import Data.Time.Calendar (Day)
import Database.Persist.Quasi
import Prelude

-- You can define all of your database entities in the entities file.
-- You can find more information on persistent and how to declare entities
-- at:
-- http://www.yesodweb.com/book/persistent/
share [mkPersist sqlSettings, mkMigrate "migrateAll"]
    $(persistFileWith lowerCaseSettings "config/models")
