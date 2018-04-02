using System;
using System.Collections.Generic;
using System.Diagnostics.CodeAnalysis;
using System.Linq;
using System.Security.Claims;
using System.Threading.Tasks;
using System.Threading;
using Envoice.Conditions;
using Envoice.MongoIdentity.Models;
using Envoice.MongoRepository;
using Microsoft.AspNetCore.Identity;
using MongoDB.Bson.Serialization.Conventions;
using MongoDB.Driver;

namespace Envoice.MongoIdentity.MongoDB
{
    public class MongoUserStore<TUser> :
        IUserStore<TUser>,
        IUserLoginStore<TUser>,
        IUserClaimStore<TUser>,
        IUserPasswordStore<TUser>,
        IUserSecurityStampStore<TUser>,
        IUserTwoFactorStore<TUser>,
        IUserEmailStore<TUser>,
        IUserLockoutStore<TUser>,
        IUserPhoneNumberStore<TUser>
        where TUser : MongoIdentityUser
    {
        private static bool _initialized = false;
        private static object _initializationLock = new object();
        private static object _initializationTarget;
        private readonly bool _disableIndexes;
        private readonly IRepository<TUser> _usersRepository;
        private readonly IRepositoryManager<TUser> _usersRepositoryManager;

        static MongoUserStore()
        {
            MongoConfig.EnsureConfigured();
        }

        /// <summary>
        /// Creates a new mongo user store.
        /// </summary>
        /// <param name="connectionString">The connection string</param>
        public MongoUserStore(string connectionString) : this(connectionString, false)
        {
        }

        /// <summary>
        /// Creates a new mongo user store.
        /// </summary>
        /// <param name="connectionString">The connection string</param>
        /// <param name="disableIndexes">Indicates if indexes should be created (cosmos)</param>
        public MongoUserStore(string connectionString, bool disableIndexes) : this(new MongoRepositoryConfig(connectionString), disableIndexes)
        {
            _disableIndexes = disableIndexes;
        }

        /// <summary>
        /// Creates a new mongo user store.
        /// </summary>
        /// <param name="config"></param>
        /// <returns></returns>
        public MongoUserStore(MongoRepositoryConfig config) : this(config, false)
        {
        }

        /// <summary>
        /// Creates a new mongo user store.
        /// </summary>
        /// <param name="config">The configuration</param>
        /// <param name="disableIndexes">Indicates if indexes should be created (cosmos)</param>
        public MongoUserStore(MongoRepositoryConfig config, bool disableIndexes)
        {
            Condition.Requires(config, "config").IsNotNull();

            _usersRepository = new MongoRepository<TUser>(config);
            _usersRepositoryManager = new MongoRepositoryManager<TUser>(config);

            if (!_disableIndexes)
            {
                EnsureIndicesCreatedAsync().GetAwaiter().GetResult();
            }
        }

        /// <summary>
        ///
        /// </summary>
        /// <param name="user"></param>
        /// <param name="cancellationToken"></param>
        /// <returns></returns>
        public async Task<IdentityResult> CreateAsync(TUser user, CancellationToken cancellationToken)
        {
            Condition.Requires(user, "user").IsNotNull();

            cancellationToken.ThrowIfCancellationRequested();

            await _usersRepository.Collection.InsertOneAsync(user, cancellationToken: cancellationToken).ConfigureAwait(false);

            return IdentityResult.Success;
        }

        /// <summary>
        ///
        /// </summary>
        /// <param name="user"></param>
        /// <param name="cancellationToken"></param>
        /// <returns></returns>
        public async Task<IdentityResult> DeleteAsync(TUser user, CancellationToken cancellationToken)
        {
            Condition.Requires(user, "user").IsNotNull();

            cancellationToken.ThrowIfCancellationRequested();

            var query = Builders<TUser>.Filter.Eq(u => u.Id, user.Id);
            var update = Builders<TUser>.Update.Set(u => u.DeletedOn, user.DeletedOn);

            await _usersRepository.Collection.UpdateOneAsync(query, update, cancellationToken: cancellationToken).ConfigureAwait(false);

            return IdentityResult.Success;
        }

        /// <summary>
        ///
        /// </summary>
        /// <param name="userId"></param>
        /// <param name="cancellationToken"></param>
        /// <returns></returns>
        public async Task<TUser> FindByIdAsync(string userId, CancellationToken cancellationToken)
        {
            Condition.Requires(userId, "userId").IsNotNullOrWhiteSpace();

            cancellationToken.ThrowIfCancellationRequested();

            var query = Builders<TUser>.Filter.And(
                Builders<TUser>.Filter.Eq(u => u.Id, userId),
                Builders<TUser>.Filter.Eq(u => u.DeletedOn, null)
            );

            return await _usersRepository.Collection.Find(query).FirstOrDefaultAsync(cancellationToken);
        }

        /// <summary>
        ///
        /// </summary>
        /// <param name="normalizedUserName"></param>
        /// <param name="cancellationToken"></param>
        /// <returns></returns>
        public async Task<TUser> FindByNameAsync(string normalizedUserName, CancellationToken cancellationToken)
        {
            Condition.Requires(normalizedUserName, "normalizedUserName").IsNotNullOrWhiteSpace();

            cancellationToken.ThrowIfCancellationRequested();

            var query = Builders<TUser>.Filter.And(
                Builders<TUser>.Filter.Eq(u => u.NormalizedUserName, normalizedUserName),
                Builders<TUser>.Filter.Eq(u => u.DeletedOn, null)
            );

            return await _usersRepository.Collection.Find(query).FirstOrDefaultAsync(cancellationToken);
        }

        /// <summary>
        ///
        /// </summary>
        /// <param name="user"></param>
        /// <param name="cancellationToken"></param>
        /// <returns></returns>
        public Task<string> GetNormalizedUserNameAsync(TUser user, CancellationToken cancellationToken)
        {
            Condition.Requires(user, "user").IsNotNull();

            return Task.FromResult(user.NormalizedUserName);
        }

        /// <summary>
        ///
        /// </summary>
        /// <param name="user"></param>
        /// <param name="cancellationToken"></param>
        /// <returns></returns>
        public Task<string> GetUserIdAsync(TUser user, CancellationToken cancellationToken)
        {
            Condition.Requires(user, "user").IsNotNull();

            return Task.FromResult(user.Id);
        }

        /// <summary>
        ///
        /// </summary>
        /// <param name="user"></param>
        /// <param name="cancellationToken"></param>
        /// <returns></returns>
        public Task<string> GetUserNameAsync(TUser user, CancellationToken cancellationToken)
        {
            Condition.Requires(user, "user").IsNotNull();

            return Task.FromResult(user.UserName);
        }

        /// <summary>
        ///
        /// </summary>
        /// <param name="user"></param>
        /// <param name="normalizedName"></param>
        /// <param name="cancellationToken"></param>
        /// <returns></returns>
        public Task SetNormalizedUserNameAsync(TUser user, string normalizedName, CancellationToken cancellationToken)
        {
            Condition.Requires(user, "user").IsNotNull();
            Condition.Requires(normalizedName, "normalizedName").IsNotNullOrWhiteSpace();

            user.SetNormalizedUserName(normalizedName);

            return Task.FromResult(0);
        }

        /// <summary>
        ///
        /// </summary>
        /// <param name="user"></param>
        /// <param name="userName"></param>
        /// <param name="cancellationToken"></param>
        /// <returns></returns>
        public Task SetUserNameAsync(TUser user, string userName, CancellationToken cancellationToken)
        {
            throw new NotSupportedException("Changing the username is not supported.");
        }

        /// <summary>
        ///
        /// </summary>
        /// <param name="user"></param>
        /// <param name="cancellationToken"></param>
        /// <returns></returns>
        public async Task<IdentityResult> UpdateAsync(TUser user, CancellationToken cancellationToken)
        {
            Condition.Requires(user, "user").IsNotNull();

            var query = Builders<TUser>.Filter.And(
                Builders<TUser>.Filter.Eq(u => u.Id, user.Id),
                Builders<TUser>.Filter.Eq(u => u.DeletedOn, null)
            );

            var replaceResult = await _usersRepository.Collection.ReplaceOneAsync(query, user, new UpdateOptions { IsUpsert = false }).ConfigureAwait(false);

            return replaceResult.IsModifiedCountAvailable && replaceResult.ModifiedCount == 1
                ? IdentityResult.Success
                : IdentityResult.Failed();
        }

        /// <summary>
        ///
        /// </summary>
        /// <param name="user"></param>
        /// <param name="login"></param>
        /// <param name="cancellationToken"></param>
        /// <returns></returns>
        public Task AddLoginAsync(TUser user, UserLoginInfo login, CancellationToken cancellationToken)
        {
            Condition.Requires(user, "user").IsNotNull();
            Condition.Requires(login, "login").IsNotNull();

            // NOTE: Not the best way to ensure uniquness.
            if (user.Logins.Any(x => x.Equals(login)))
            {
                throw new InvalidOperationException("Login already exists.");
            }

            user.AddLogin(new MongoUserLogin(login));

            return Task.FromResult(0);
        }

        /// <summary>
        ///
        /// </summary>
        /// <param name="user"></param>
        /// <param name="loginProvider"></param>
        /// <param name="providerKey"></param>
        /// <param name="cancellationToken"></param>
        /// <returns></returns>
        public Task RemoveLoginAsync(TUser user, string loginProvider, string providerKey, CancellationToken cancellationToken)
        {
            Condition.Requires(user, "user").IsNotNull();
            Condition.Requires(loginProvider, "loginProvider").IsNotNullOrWhiteSpace();
            Condition.Requires(providerKey, "providerKey").IsNotNullOrWhiteSpace();

            var login = new UserLoginInfo(loginProvider, providerKey, string.Empty);
            var loginToRemove = user.Logins.FirstOrDefault(x => x.Equals(login));

            if (loginToRemove != null)
            {
                user.RemoveLogin(loginToRemove);
            }

            return Task.FromResult(0);
        }

        /// <summary>
        ///
        /// </summary>
        /// <param name="user"></param>
        /// <param name="cancellationToken"></param>
        /// <returns></returns>
        public Task<IList<UserLoginInfo>> GetLoginsAsync(TUser user, CancellationToken cancellationToken)
        {
            Condition.Requires(user, "user").IsNotNull();

            var logins = user.Logins.Select(login =>
                new UserLoginInfo(login.LoginProvider, login.ProviderKey, login.ProviderDisplayName));

            return Task.FromResult<IList<UserLoginInfo>>(logins.ToList());
        }

        /// <summary>
        ///
        /// </summary>
        /// <param name="loginProvider"></param>
        /// <param name="providerKey"></param>
        /// <param name="cancellationToken"></param>
        /// <returns></returns>
        public Task<TUser> FindByLoginAsync(string loginProvider, string providerKey, CancellationToken cancellationToken)
        {
            Condition.Requires(loginProvider, "loginProvider").IsNotNullOrWhiteSpace();
            Condition.Requires(providerKey, "providerKey").IsNotNullOrWhiteSpace();

            var notDeletedQuery = Builders<TUser>.Filter.Eq(u => u.DeletedOn, null);
            var loginQuery = Builders<TUser>.Filter.ElemMatch(usr => usr.Logins,
                Builders<MongoUserLogin>.Filter.And(
                    Builders<MongoUserLogin>.Filter.Eq(lg => lg.LoginProvider, loginProvider),
                    Builders<MongoUserLogin>.Filter.Eq(lg => lg.ProviderKey, providerKey)
                )
            );

            var query = Builders<TUser>.Filter.And(notDeletedQuery, loginQuery);

            return _usersRepository.Collection.Find(query).FirstOrDefaultAsync();
        }

        /// <summary>
        ///
        /// </summary>
        /// <param name="user"></param>
        /// <param name="cancellationToken"></param>
        /// <returns></returns>
        public Task<IList<Claim>> GetClaimsAsync(TUser user, CancellationToken cancellationToken)
        {
            Condition.Requires(user, "user").IsNotNull();

            var claims = user.Claims.Select(clm => new Claim(clm.ClaimType, clm.ClaimValue)).ToList();

            return Task.FromResult<IList<Claim>>(claims);
        }

        /// <summary>
        ///
        /// </summary>
        /// <param name="user"></param>
        /// <param name="claims"></param>
        /// <param name="cancellationToken"></param>
        /// <returns></returns>
        public Task AddClaimsAsync(TUser user, IEnumerable<Claim> claims, CancellationToken cancellationToken)
        {
            Condition.Requires(user, "user").IsNotNull();
            Condition.Requires(claims, "claims").IsNotNull();

            foreach (var claim in claims)
            {
                user.AddClaim(claim);
            }

            return Task.FromResult(0);
        }

        /// <summary>
        ///
        /// </summary>
        /// <param name="user"></param>
        /// <param name="claim"></param>
        /// <param name="newClaim"></param>
        /// <param name="cancellationToken"></param>
        /// <returns></returns>
        public Task ReplaceClaimAsync(TUser user, Claim claim, Claim newClaim, CancellationToken cancellationToken)
        {
            Condition.Requires(user, "user").IsNotNull();
            Condition.Requires(claim, "claim").IsNotNull();
            Condition.Requires(newClaim, "newClaim").IsNotNull();

            user.RemoveClaim(new MongoUserClaim(claim));
            user.AddClaim(newClaim);

            return Task.FromResult(0);
        }

        /// <summary>
        ///
        /// </summary>
        /// <param name="user"></param>
        /// <param name="claims"></param>
        /// <param name="cancellationToken"></param>
        /// <returns></returns>
        public Task RemoveClaimsAsync(TUser user, IEnumerable<Claim> claims, CancellationToken cancellationToken)
        {
            Condition.Requires(user, "user").IsNotNull();
            Condition.Requires(claims, "claims").IsNotNull();

            foreach (var claim in claims)
            {
                user.RemoveClaim(new MongoUserClaim(claim));
            }

            return Task.FromResult(0);
        }

        /// <summary>
        ///
        /// </summary>
        /// <param name="claim"></param>
        /// <param name="cancellationToken"></param>
        /// <returns></returns>
        public async Task<IList<TUser>> GetUsersForClaimAsync(Claim claim, CancellationToken cancellationToken)
        {
            Condition.Requires(claim, "claim").IsNotNull();

            var notDeletedQuery = Builders<TUser>.Filter.Eq(u => u.DeletedOn, null);
            var claimQuery = Builders<TUser>.Filter.ElemMatch(usr => usr.Claims,
                Builders<MongoUserClaim>.Filter.And(
                    Builders<MongoUserClaim>.Filter.Eq(c => c.ClaimType, claim.Type),
                    Builders<MongoUserClaim>.Filter.Eq(c => c.ClaimValue, claim.Value)
                )
            );

            var query = Builders<TUser>.Filter.And(notDeletedQuery, claimQuery);
            var users = await _usersRepository.Collection.Find(query).ToListAsync().ConfigureAwait(false);

            return users;
        }

        /// <summary>
        ///
        /// </summary>
        /// <param name="user"></param>
        /// <param name="passwordHash"></param>
        /// <param name="cancellationToken"></param>
        /// <returns></returns>
        public Task SetPasswordHashAsync(TUser user, string passwordHash, CancellationToken cancellationToken)
        {
            Condition.Requires(user, "user").IsNotNull();
            Condition.Requires(passwordHash, "passwordHash").IsNotNullOrWhiteSpace();

            user.SetPasswordHash(passwordHash);

            return Task.FromResult(0);
        }

        /// <summary>
        ///
        /// </summary>
        /// <param name="user"></param>
        /// <param name="cancellationToken"></param>
        /// <returns></returns>
        public Task<string> GetPasswordHashAsync(TUser user, CancellationToken cancellationToken)
        {
            Condition.Requires(user, "user").IsNotNull();

            return Task.FromResult(user.PasswordHash);
        }

        /// <summary>
        ///
        /// </summary>
        /// <param name="user"></param>
        /// <param name="cancellationToken"></param>
        /// <returns></returns>
        public Task<bool> HasPasswordAsync(TUser user, CancellationToken cancellationToken)
        {
            Condition.Requires(user, "user").IsNotNull();

            return Task.FromResult(user.PasswordHash != null);
        }

        /// <summary>
        ///
        /// </summary>
        /// <param name="user"></param>
        /// <param name="stamp"></param>
        /// <param name="cancellationToken"></param>
        /// <returns></returns>
        public Task SetSecurityStampAsync(TUser user, string stamp, CancellationToken cancellationToken)
        {
            Condition.Requires(user, "user").IsNotNull();
            Condition.Requires(stamp, "stamp").IsNotNullOrWhiteSpace();

            user.SetSecurityStamp(stamp);

            return Task.FromResult(0);
        }

        /// <summary>
        ///
        /// </summary>
        /// <param name="user"></param>
        /// <param name="cancellationToken"></param>
        /// <returns></returns>
        public Task<string> GetSecurityStampAsync(TUser user, CancellationToken cancellationToken)
        {
            Condition.Requires(user, "user").IsNotNull();

            return Task.FromResult(user.SecurityStamp);
        }

        /// <summary>
        ///
        /// </summary>
        /// <param name="user"></param>
        /// <param name="enabled"></param>
        /// <param name="cancellationToken"></param>
        /// <returns></returns>
        public Task SetTwoFactorEnabledAsync(TUser user, bool enabled, CancellationToken cancellationToken)
        {
            Condition.Requires(user, "user").IsNotNull();

            if (enabled)
            {
                user.EnableTwoFactorAuthentication();
            }
            else
            {
                user.DisableTwoFactorAuthentication();
            }

            return Task.FromResult(0);
        }

        /// <summary>
        ///
        /// </summary>
        /// <param name="user"></param>
        /// <param name="cancellationToken"></param>
        /// <returns></returns>
        public Task<bool> GetTwoFactorEnabledAsync(TUser user, CancellationToken cancellationToken)
        {
            Condition.Requires(user, "user").IsNotNull();

            return Task.FromResult(user.IsTwoFactorEnabled);
        }

        /// <summary>
        ///
        /// </summary>
        /// <param name="user"></param>
        /// <param name="email"></param>
        /// <param name="cancellationToken"></param>
        /// <returns></returns>
        public Task SetEmailAsync(TUser user, string email, CancellationToken cancellationToken)
        {
            Condition.Requires(user, "user").IsNotNull();
            Condition.Requires(email, "email").IsNotNull();

            user.SetEmail(email);

            return Task.FromResult(0);
        }

        /// <summary>
        ///
        /// </summary>
        /// <param name="user"></param>
        /// <param name="cancellationToken"></param>
        /// <returns></returns>
        public Task<string> GetEmailAsync(TUser user, CancellationToken cancellationToken)
        {
            Condition.Requires(user, "user").IsNotNull();

            var email = (user.Email != null) ? user.Email.Value : null;

            return Task.FromResult(email);
        }

        /// <summary>
        ///
        /// </summary>
        /// <param name="user"></param>
        /// <param name="cancellationToken"></param>
        /// <returns></returns>
        public Task<bool> GetEmailConfirmedAsync(TUser user, CancellationToken cancellationToken)
        {
            Condition.Requires(user, "user").IsNotNull();

            if (null == user.Email)
            {
                throw new InvalidOperationException("Cannot get the confirmation status of the e-mail since the user doesn't have an e-mail.");
            }

            return Task.FromResult(user.Email.IsConfirmed());
        }

        /// <summary>
        ///
        /// </summary>
        /// <param name="user"></param>
        /// <param name="confirmed"></param>
        /// <param name="cancellationToken"></param>
        /// <returns></returns>
        public Task SetEmailConfirmedAsync(TUser user, bool confirmed, CancellationToken cancellationToken)
        {
            Condition.Requires(user, "user").IsNotNull();

            if (null == user.Email)
            {
                throw new InvalidOperationException("Cannot set the confirmation status of the e-mail because user doesn't have an e-mail.");
            }

            if (confirmed)
            {
                user.Email.SetConfirmed();
            }
            else
            {
                user.Email.SetUnconfirmed();
            }

            return Task.FromResult(0);
        }

        /// <summary>
        ///
        /// </summary>
        /// <param name="normalizedEmail"></param>
        /// <param name="cancellationToken"></param>
        /// <returns></returns>
        public Task<TUser> FindByEmailAsync(string normalizedEmail, CancellationToken cancellationToken)
        {
            Condition.Requires(normalizedEmail, "normalizedEmail").IsNotNullOrWhiteSpace();

            var query = Builders<TUser>.Filter.And(
                Builders<TUser>.Filter.Eq(u => u.Email.NormalizedValue, normalizedEmail),
                Builders<TUser>.Filter.Eq(u => u.DeletedOn, null)
            );

            return _usersRepository.Collection.Find(query).FirstOrDefaultAsync(cancellationToken);
        }

        /// <summary>
        ///
        /// </summary>
        /// <param name="user"></param>
        /// <param name="cancellationToken"></param>
        /// <returns></returns>
        public Task<string> GetNormalizedEmailAsync(TUser user, CancellationToken cancellationToken)
        {
            Condition.Requires(user, "user").IsNotNull();

            var normalizedEmail = (user.Email != null) ? user.Email.NormalizedValue : null;

            return Task.FromResult(normalizedEmail);
        }

        /// <summary>
        ///
        /// </summary>
        /// <param name="user"></param>
        /// <param name="normalizedEmail"></param>
        /// <param name="cancellationToken"></param>
        /// <returns></returns>
        public Task SetNormalizedEmailAsync(TUser user, string normalizedEmail, CancellationToken cancellationToken)
        {
            Condition.Requires(user, "user").IsNotNull();

            // This method can be called even if user doesn't have an e-mail.
            // Act cool in this case and gracefully handle.
            // More info: https://github.com/aspnet/Identity/issues/645

            if (normalizedEmail != null && user.Email != null)
            {
                user.Email.SetNormalizedEmail(normalizedEmail);
            }

            return Task.FromResult(0);
        }

        /// <summary>
        ///
        /// </summary>
        /// <param name="user"></param>
        /// <param name="cancellationToken"></param>
        /// <returns></returns>
        public Task<DateTimeOffset?> GetLockoutEndDateAsync(TUser user, CancellationToken cancellationToken)
        {
            Condition.Requires(user, "user").IsNotNull();

            var lockoutEndDate = user.LockoutEndDate != null
                ? new DateTimeOffset(user.LockoutEndDate.Instant)
                : default(DateTimeOffset?);

            return Task.FromResult(lockoutEndDate);
        }

        /// <summary>
        ///
        /// </summary>
        /// <param name="user"></param>
        /// <param name="lockoutEnd"></param>
        /// <param name="cancellationToken"></param>
        /// <returns></returns>
        public Task SetLockoutEndDateAsync(TUser user, DateTimeOffset? lockoutEnd, CancellationToken cancellationToken)
        {
            Condition.Requires(user, "user").IsNotNull();

            if (lockoutEnd != null)
            {
                user.LockUntil(lockoutEnd.Value.UtcDateTime);
            }

            return Task.FromResult(0);
        }

        /// <summary>
        ///
        /// </summary>
        /// <param name="user"></param>
        /// <param name="cancellationToken"></param>
        /// <returns></returns>
        public async Task<int> IncrementAccessFailedCountAsync(TUser user, CancellationToken cancellationToken)
        {
            Condition.Requires(user, "user").IsNotNull();

            var filter = Builders<TUser>.Filter.Eq(u => u.Id, user.Id);
            var update = Builders<TUser>.Update.Inc(usr => usr.AccessFailedCount, 1);
            var findOneAndUpdateOptions = new FindOneAndUpdateOptions<TUser, int>
            {
                ReturnDocument = ReturnDocument.After,
                Projection = Builders<TUser>.Projection.Expression(usr => usr.AccessFailedCount)
            };

            var newCount = await _usersRepository.Collection
                .FindOneAndUpdateAsync<int>(filter, update, findOneAndUpdateOptions)
                .ConfigureAwait(false);

            user.SetAccessFailedCount(newCount);

            return newCount;
        }

        /// <summary>
        ///
        /// </summary>
        /// <param name="user"></param>
        /// <param name="cancellationToken"></param>
        /// <returns></returns>
        public Task ResetAccessFailedCountAsync(TUser user, CancellationToken cancellationToken)
        {
            Condition.Requires(user, "user").IsNotNull();

            user.ResetAccessFailedCount();

            return Task.FromResult(0);
        }

        /// <summary>
        ///
        /// </summary>
        /// <param name="user"></param>
        /// <param name="cancellationToken"></param>
        /// <returns></returns>
        public Task<int> GetAccessFailedCountAsync(TUser user, CancellationToken cancellationToken)
        {
            Condition.Requires(user, "user").IsNotNull();

            return Task.FromResult(user.AccessFailedCount);
        }

        /// <summary>
        ///
        /// </summary>
        /// <param name="user"></param>
        /// <param name="cancellationToken"></param>
        /// <returns></returns>
        public Task<bool> GetLockoutEnabledAsync(TUser user, CancellationToken cancellationToken)
        {
            Condition.Requires(user, "user").IsNotNull();

            return Task.FromResult(user.IsLockoutEnabled);
        }

        /// <summary>
        ///
        /// </summary>
        /// <param name="user"></param>
        /// <param name="enabled"></param>
        /// <param name="cancellationToken"></param>
        /// <returns></returns>
        public Task SetLockoutEnabledAsync(TUser user, bool enabled, CancellationToken cancellationToken)
        {
            Condition.Requires(user, "user").IsNotNull();

            if (enabled)
            {
                user.EnableLockout();
            }
            else
            {
                user.DisableLockout();
            }

            return Task.FromResult(0);
        }

        /// <summary>
        ///
        /// </summary>
        /// <param name="user"></param>
        /// <param name="phoneNumber"></param>
        /// <param name="cancellationToken"></param>
        /// <returns></returns>
        public Task SetPhoneNumberAsync(TUser user, string phoneNumber, CancellationToken cancellationToken)
        {
            Condition.Requires(user, "user").IsNotNull();
            Condition.Requires(phoneNumber, "phoneNumber").IsNotNullOrWhiteSpace();

            if (phoneNumber == null)
            {
                throw new ArgumentNullException(nameof(phoneNumber));
            }

            user.SetPhoneNumber(phoneNumber);

            return Task.FromResult(0);
        }

        /// <summary>
        ///
        /// </summary>
        /// <param name="user"></param>
        /// <param name="cancellationToken"></param>
        /// <returns></returns>
        public Task<string> GetPhoneNumberAsync(TUser user, CancellationToken cancellationToken)
        {
            Condition.Requires(user, "user").IsNotNull();

            return Task.FromResult(user.PhoneNumber?.Value);
        }

        /// <summary>
        ///
        /// </summary>
        /// <param name="user"></param>
        /// <param name="cancellationToken"></param>
        /// <returns></returns>
        public Task<bool> GetPhoneNumberConfirmedAsync(TUser user, CancellationToken cancellationToken)
        {
            Condition.Requires(user, "user").IsNotNull();

            if (null == user.PhoneNumber)
            {
                throw new InvalidOperationException("Cannot get the confirmation status of the phone number since the user doesn't have a phone number.");
            }

            return Task.FromResult(user.PhoneNumber.IsConfirmed());
        }

        public Task SetPhoneNumberConfirmedAsync(TUser user, bool confirmed, CancellationToken cancellationToken)
        {
            Condition.Requires(user, "user").IsNotNull();

            if (null == user.PhoneNumber)
            {
                throw new InvalidOperationException("Cannot set the confirmation status of the phone number since the user doesn't have a phone number.");
            }

            user.PhoneNumber.SetConfirmed();

            return Task.FromResult(0);
        }

        /// <summary>
        ///
        /// </summary>
        public void Dispose()
        {
        }

        private async Task EnsureIndicesCreatedAsync()
        {
            var obj = LazyInitializer.EnsureInitialized(ref _initializationTarget, ref _initialized, ref _initializationLock, () =>
            {
                return EnsureIndicesCreatedImplAsync();
            });

            if (obj != null)
            {
                var taskToAwait = (Task)obj;
                await taskToAwait.ConfigureAwait(false);
            }
        }

        private async Task EnsureIndicesCreatedImplAsync()
        {
            var tasks = new[]
            {
                _usersRepositoryManager.EnsureIndexAsync(o => o.Email.Value, false, true, false),
                _usersRepositoryManager.EnsureIndexAsync(new []{"Logins.LoginProvider", "Logins.ProviderKey"}, false, true, true)
            };

            await Task.WhenAll(tasks).ConfigureAwait(false);
        }
    }
}
