using System;
using System.Collections.Generic;
using System.Linq;
using MongoDB.Driver;

namespace Envoice.MongoIdentity.Helpers
{
  internal static class Util
  {
    /// <summary>
    /// Converts an IEnumberable of T to a IList of T
    /// </summary>
    /// <typeparam name="T"></typeparam>
    /// <param name="enumerable">The enumerable.</param>
    /// <returns>IList{``0}.</returns>
    public static IList<T> ToIList<T>(this IEnumerable<T> enumerable)
    {
      return enumerable.ToList();
    }

    /// <summary>
    ///     Gets the database from connection string.
    /// </summary>
    /// <param name="connectionString">The connection string.</param>
    /// <returns>MongoDatabase.</returns>
    /// <exception cref="System.Exception">No database name specified in connection string</exception>
    public static IMongoDatabase GetDatabaseFromSqlStyle(string connectionString)
    {
      var mongoUrl = new MongoUrl(connectionString);
      MongoClientSettings settings = MongoClientSettings.FromUrl(mongoUrl);
      IMongoClient client = new MongoClient(settings);
      if (mongoUrl.DatabaseName == null)
      {
        throw new Exception("No database name specified in connection string");
      }
      return client.GetDatabase(mongoUrl.DatabaseName);
    }

    /// <summary>
    ///     Gets the database from URL.
    /// </summary>
    /// <param name="url">The URL.</param>
    /// <returns>MongoDatabase.</returns>
    public static IMongoDatabase GetDatabaseFromUrl(MongoUrl url)
    {
      IMongoClient client = new MongoClient(url);
      if (url.DatabaseName == null)
      {
        throw new Exception("No database name specified in connection string");
      }
      return client.GetDatabase(url.DatabaseName); // WriteConcern defaulted to Acknowledged
    }

    /// <summary>
    ///     Uses connectionString to connect to server and then uses databae name specified.
    /// </summary>
    /// <param name="connectionString">The connection string.</param>
    /// <param name="dbName">Name of the database.</param>
    /// <returns>MongoDatabase.</returns>
    public static IMongoDatabase GetDatabase(string connectionString, string dbName)
    {
      var client = new MongoClient(connectionString);
      return client.GetDatabase(dbName);
    }
  }
}