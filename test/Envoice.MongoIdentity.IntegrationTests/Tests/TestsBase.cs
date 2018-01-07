using MongoDB.Driver;

namespace Envoice.MongoIdentity.IntegrationTests.Tests
{
    /// <summary>
    /// Setup and teardown of database
    /// </summary>
    public abstract class TestsBase
    {
        protected TestsBase() 
        {
            var url = new MongoUrl(Configuration.Database.ConnectionString);
            var client = new MongoClient(url);
            client.DropDatabase(url.DatabaseName);
        }
    }
}