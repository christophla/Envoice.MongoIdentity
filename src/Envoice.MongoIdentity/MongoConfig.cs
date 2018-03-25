using Microsoft.AspNetCore.Identity;
using MongoDB.Bson.Serialization;
using MongoDB.Bson.Serialization.Conventions;
using System;
using System.Threading;
using MongoDB.Bson.Serialization.Serializers;
using MongoDB.Bson;
using MongoDB.Bson.Serialization.IdGenerators;
using Envoice.MongoIdentity.Models;
using Envoice.MongoRepository;

namespace Envoice.MongoIdentity.MongoDB
{
    /// <summary>
    /// Configures the mongo db driver conventions.
    /// </summary>
    internal static class MongoConfig
    {
        private static bool _initialized = false;
        private static object _initializationLock = new object();
        private static object _initializationTarget;

        /// <summary>
        /// Ensures that the conventions have been configured.
        /// </summary>
        public static void EnsureConfigured()
        {
            LazyInitializer.EnsureInitialized(ref _initializationTarget, ref _initialized, ref _initializationLock, () =>
            {
                Configure();
                return null;
            });
        }

        #region [ Private Methods ]

        private static void Configure()
        {
            RegisterConventions();

            BsonClassMap.RegisterClassMap<MongoIdentityUser>(cm =>
            {
                cm.AutoMap();
                cm.MapCreator(user => new MongoIdentityUser(user.UserName, user.Email));
            });

            BsonClassMap.RegisterClassMap<MongoUserClaim>(cm =>
            {
                cm.AutoMap();
                cm.MapCreator(c => new MongoUserClaim(c.ClaimType, c.ClaimValue));
            });

            BsonClassMap.RegisterClassMap<MongoUserEmail>(cm =>
            {
                cm.AutoMap();
                cm.MapCreator(cr => new MongoUserEmail(cr.Value));
            });

            BsonClassMap.RegisterClassMap<MongoUserContactRecord>(cm =>
            {
                cm.AutoMap();
            });

            BsonClassMap.RegisterClassMap<MongoUserPhoneNumber>(cm =>
            {
                cm.AutoMap();
                cm.MapCreator(cr => new MongoUserPhoneNumber(cr.Value));
            });

            BsonClassMap.RegisterClassMap<MongoUserLogin>(cm =>
            {
                cm.AutoMap();
                cm.MapCreator(l => new MongoUserLogin(new UserLoginInfo(l.LoginProvider, l.ProviderKey, l.ProviderDisplayName)));
            });

            BsonClassMap.RegisterClassMap<Occurrence>(cm =>
            {
                cm.AutoMap();
                cm.MapCreator(cr => new Occurrence(cr.Instant));
                cm.MapMember(x => x.Instant).SetSerializer(new DateTimeSerializer(DateTimeKind.Utc, BsonType.Document));
            });
        }

        private static void RegisterConventions()
        {
            var pack = new ConventionPack
            {
                new IgnoreIfNullConvention(false),
                new CamelCaseElementNameConvention(),
            };

            ConventionRegistry.Register("Envoice.MongoIdentity", pack, IsConventionApplicable);
        }

        private static bool IsConventionApplicable(Type type)
        {
            return type == typeof(MongoIdentityUser)
                || type == typeof(MongoUserClaim)
                || type == typeof(MongoUserContactRecord)
                || type == typeof(MongoUserEmail)
                || type == typeof(MongoUserLogin)
                || type == typeof(MongoUserPhoneNumber)
                || type == typeof(ConfirmationOccurrence)
                || type == typeof(FutureOccurrence)
                || type == typeof(Occurrence);
        }

        #endregion
    }
}
