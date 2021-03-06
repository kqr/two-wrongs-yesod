{-# LANGUAGE OverloadedStrings #-}
module Handler.Site where

import Import
import Yesod.Form.Bootstrap3
import Yesod.AtomFeed
import Data.Time.Calendar (showGregorian, Day(ModifiedJulianDay))
import Data.Time.Clock (utctDay, getCurrentTime, UTCTime(UTCTime))
import Data.Maybe (listToMaybe, maybe)



getHomeR :: Handler Html
getHomeR = do
  today <- liftIO $ utctDay <$> getCurrentTime
  entries <- runDB (selectList [EntryPublished <=. Just today] [Desc EntryPublished])
  defaultLayout $ do
    setTitle "Two Wrongs, Recent"
    $(widgetFile "article_list")


getAboutR :: Handler Html
getAboutR =
  defaultLayout $ do
    setTitle "Two Wrongs, About"
    $(widgetFile "about")


getAtomR :: Handler RepAtom
getAtomR = do
  today <- liftIO $ utctDay <$> getCurrentTime
  entries <- runDB (selectList [EntryPublished <=. Just today] [Desc EntryPublished, LimitTo 20])

  let noTime = maybe (UTCTime (ModifiedJulianDay 0) 0)

  let atomEntry entry = FeedEntry
        { feedEntryLink    = EntryR (entrySlug entry)
        , feedEntryUpdated = noTime (flip UTCTime 0) (entryPublished entry)
        , feedEntryTitle   = entryTitle entry
        , feedEntryContent = entryContent entry
        }

  let atomEntries = map (atomEntry . entityVal) entries

  atomFeed Feed
    { feedTitle       = "Two Wrongs"
    , feedLinkSelf    = AtomR
    , feedLinkHome    = HomeR
    , feedAuthor      = "kqr"
    , feedUpdated     = noTime feedEntryUpdated (listToMaybe atomEntries)
    , feedEntries     = atomEntries
    , feedDescription = "Latest articles on Two Wrongs"
    , feedLanguage    = "en-us"
    }




getDraftsR :: Handler Html
getDraftsR = do
  today <- liftIO $ utctDay <$> getCurrentTime
  entries <- runDB (selectList ([EntryPublished ==. Nothing] ||. [EntryPublished >. Just today]) [Asc EntryId])
  defaultLayout $ do
    setTitle "Two Wrongs, Drafts"
    $(widgetFile "article_list")



getEntryR :: Text -> Handler Html
getEntryR slug = do
  entryRec <- runDB (getBy404 (UniqueSlug slug))
  author <- isAuthor
  defaultLayout $ do
    setTitle ("Two Wrongs, " <> toHtml (entryTitle (entityVal entryRec)))
    $(widgetFile "detail")



entryForm :: Maybe Entry -> Form Entry
entryForm existing = renderBootstrap3 BootstrapBasicForm $
  Entry <$> areq textField (bfs ("Title: " :: Text)) (fmap entryTitle existing)
        <*> areq textField (bfs ("Slug: " :: Text)) (fmap entrySlug existing)
        <*> aopt dayField (bfs ("Published: " :: Text)) (fmap entryPublished existing)
        <*> areq htmlField (bfs ("Content: " :: Text)) (fmap entryContent existing)

getNewR :: Handler Html
getNewR = do
  let next = NewR
  (formFields, enctype) <- generateFormPost (entryForm Nothing)
  defaultLayout $ do
    setTitle "Two Wrongs, Create New Entry"
    $(widgetFile "entryform")

postNewR :: Handler Html
postNewR = do
  let next = NewR
  ((result, formFields), enctype) <- runFormPost (entryForm Nothing)
  case result of
    FormSuccess entry -> do
      exists <- runDB (insertUnique entry)
      case exists of
        Just _  -> setMessage "Blog entry successfully added" >> redirect (EntryR (entrySlug entry))
        Nothing -> setMessage "That slug already leads to a different entry"
    _ -> setMessage "Invalid form submission, check for errors"
        
  defaultLayout $ do
    setTitle "Two Wrongs, Create New Entry"
    $(widgetFile "entryform")


getEditR :: EntryId -> Handler Html
getEditR eid = do
  let next = EditR eid
  entry <- runDB (get404 eid)
  (formFields, enctype) <- generateFormPost (entryForm (Just entry))
  defaultLayout $ do
    setTitle "Two Wrongs, Edit Entry"
    $(widgetFile "entryform")

postEditR :: EntryId -> Handler Html
postEditR eid = do
  let next = EditR eid
  ((result, formFields), enctype) <- runFormPost (entryForm Nothing)
  case result of
    FormSuccess entry -> do
      runDB (repsert eid entry)
      setMessage "Blog entry successfully edited"
      redirect (EntryR (entrySlug entry))

    _ -> setMessage "Invalid form submission, check for errors"
        
  defaultLayout $ do
    setTitle "Two Wrongs, Edit Entry"
    $(widgetFile "entryform")



authorForm :: Form Authors
authorForm = renderBootstrap3 BootstrapBasicForm $
  Authors <$> areq textField (bfs ("UID: " :: Text)) Nothing

getAuthorsR :: Handler Html
getAuthorsR = do
  (formFields, enctype) <- generateFormPost authorForm

  authors <- runDB (selectList [] [Desc AuthorsId])
  defaultLayout $ do
    setTitle "Two Wrongs, Authorized Authors"
    $(widgetFile "authors")

postAuthorsR :: Handler Html
postAuthorsR = do
  ((result, formFields), enctype) <- runFormPost authorForm
  formFailure <- case result of
    FormSuccess author -> do
      exists <- runDB (insertUnique author)
      case exists of
        Just _  -> setMessage "Author successfully added!" >> redirect AuthorsR
        Nothing -> setMessage "An author with that UID already exists"
    _ -> setMessage "Invalid form submission, check for errors"
        
  authors <- runDB (selectList [] [Desc AuthorsId])
  defaultLayout $ do
    setTitle "Two Wrongs, Authorized Authors"
    $(widgetFile "authors")




