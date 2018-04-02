using System;
using System.Collections.Generic;
using System.Diagnostics.CodeAnalysis;
using System.Security.Claims;
using Envoice.MongoIdentity.Models;
using Envoice.MongoRepository;
using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;

namespace Envoice.MongoIdentity.MongoDB
{
    /// <summary>
    /// A mongo identity user.
    /// </summary>
    public class MongoIdentityUser : Entity
    {
        private List<MongoUserClaim> _claims;
        private List<MongoUserLogin> _logins;

        /// <summary>
        /// Intializes a new user
        /// </summary>
        /// <param name="userName">The username</param>
        /// <param name="email">The email</param>
        public MongoIdentityUser(string userName, string email) : this(userName)
        {
            if (email != null)
            {
                Email = new MongoUserEmail(email);
            }
        }

        /// <summary>
        /// Intializes a new user
        /// </summary>
        /// <param name="userName">The username</param>
        /// <param name="email">The mongo email</param>
        public MongoIdentityUser(string userName, MongoUserEmail email) : this(userName)
        {
            if (email != null)
            {
                Email = email;
            }
        }

        /// <summary>
        /// Intializes a new user
        /// </summary>
        /// <param name="userName">The username</param>
        public MongoIdentityUser(string userName)
        {
            if (userName == null)
            {
                throw new ArgumentNullException(nameof(userName));
            }

            Id = ObjectId.GenerateNewId().ToString();
            UserName = userName;

            EnsureClaimsIsSet();
            EnsureLoginsIsSet();
        }

        /// <summary>
        /// The username
        /// </summary>
        public string UserName { get; private set; }

        /// <summary>
        /// The normalized username
        /// </summary>
        /// <returns></returns>
        public string NormalizedUserName { get; private set; }

        /// <summary>
        /// The user email
        /// </summary>
        /// <returns></returns>
        public MongoUserEmail Email { get; private set; }

        /// <summary>
        /// The user phone number
        /// </summary>
        /// <returns></returns>
        public MongoUserPhoneNumber PhoneNumber { get; private set; }

        /// <summary>
        /// The password hash
        /// </summary>
        public string PasswordHash { get; private set; }

        /// <summary>
        /// The security stamp
        /// </summary>
        /// <returns></returns>
        public string SecurityStamp { get; private set; }

        /// <summary>
        /// Indicates if two-fact auth is enabled for this user
        /// </summary>
        /// <returns></returns>
        public bool IsTwoFactorEnabled { get; private set; }

        /// <summary>
        /// The user claims collection
        /// </summary>
        [BsonIgnoreIfNull]
        public IEnumerable<MongoUserClaim> Claims
        {
            get
            {
                EnsureClaimsIsSet();
                return _claims;
            }

            private set
            {
                EnsureClaimsIsSet();
                if (value != null)
                {
                    _claims.AddRange(value);
                }
            }
        }

        /// <summary>
        /// The user account login
        /// </summary>
        /// <returns></returns>
        [BsonIgnoreIfNull]
        public IEnumerable<MongoUserLogin> Logins
        {
            get
            {
                EnsureLoginsIsSet();
                return _logins;
            }

            private set
            {
                EnsureLoginsIsSet();
                if (value != null)
                {
                    _logins.AddRange(value);
                }
            }
        }

        /// <summary>
        /// The number of authentication failures
        /// </summary>
        /// <returns></returns>
        public int AccessFailedCount { get; private set; }

        /// <summary>
        /// Indicates if the user is locked out
        /// </summary>
        /// <returns></returns>
        public bool IsLockoutEnabled { get; private set; }

        /// <summary>
        /// The date when the account lockout will end
        /// </summary>
        /// <returns></returns>
        public FutureOccurrence LockoutEndDate { get; private set; }

        /// <summary>
        /// Indicates the date the account was deleted
        /// </summary>
        /// <returns></returns>
        public Occurrence DeletedOn { get; private set; }

        /// <summary>
        /// Enables two-factor authentication for the account
        /// </summary>
        public virtual void EnableTwoFactorAuthentication()
        {
            IsTwoFactorEnabled = true;
        }

        /// <summary>
        /// Disables two-factor authentication for the account
        /// </summary>
        public virtual void DisableTwoFactorAuthentication()
        {
            IsTwoFactorEnabled = false;
        }

        /// <summary>
        /// Locks out the account
        /// </summary>
        public virtual void EnableLockout()
        {
            IsLockoutEnabled = true;
        }

        /// <summary>
        /// Re-enables a locked account
        /// </summary>
        public virtual void DisableLockout()
        {
            IsLockoutEnabled = false;
        }

        /// <summary>
        /// Sets the user email
        /// </summary>
        /// <param name="email">The email address</param>
        public virtual void SetEmail(string email)
        {
            var mongoUserEmail = new MongoUserEmail(email);
            SetEmail(mongoUserEmail);
        }

        /// <summary>
        /// Sets the user email
        /// </summary>
        /// <param name="mongoUserEmail">The email address</param>
        public virtual void SetEmail(MongoUserEmail mongoUserEmail)
        {
            Email = mongoUserEmail;
        }

        /// <summary>
        /// Sets the normalized username
        /// </summary>
        /// <param name="normalizedUserName">The normalized username</param>
        public virtual void SetNormalizedUserName(string normalizedUserName)
        {
            if (normalizedUserName == null)
            {
                throw new ArgumentNullException(nameof(normalizedUserName));
            }

            NormalizedUserName = normalizedUserName;
        }

        /// <summary>
        /// Sets the phone number
        /// </summary>
        /// <param name="phoneNumber">The phone number</param>
        public virtual void SetPhoneNumber(string phoneNumber)
        {
            var mongoUserPhoneNumber = new MongoUserPhoneNumber(phoneNumber);
            SetPhoneNumber(mongoUserPhoneNumber);
        }

        /// <summary>
        /// Sets the phone number
        /// </summary>
        /// <param name="mongoUserPhoneNumber">The mongo user phone number</param>
        public virtual void SetPhoneNumber(MongoUserPhoneNumber mongoUserPhoneNumber)
        {
            PhoneNumber = mongoUserPhoneNumber;
        }

        /// <summary>
        /// Sets the password hash
        /// </summary>
        /// <param name="passwordHash">The password hash</param>
        public virtual void SetPasswordHash(string passwordHash)
        {
            PasswordHash = passwordHash;
        }

        /// <summary>
        /// Sets the security stamp
        /// </summary>
        /// <param name="securityStamp">The security stamp</param>
        public virtual void SetSecurityStamp(string securityStamp)
        {
            SecurityStamp = securityStamp;
        }

        /// <summary>
        /// Sets the number of failed authentication attempts
        /// </summary>
        /// <param name="accessFailedCount">The number of failed attempts</param>
        public virtual void SetAccessFailedCount(int accessFailedCount)
        {
            AccessFailedCount = accessFailedCount;
        }

        /// <summary>
        /// Resets the authentication failues to zero
        /// </summary>
        public virtual void ResetAccessFailedCount()
        {
            AccessFailedCount = 0;
        }

        /// <summary>
        /// Locks the account until a future date
        /// </summary>
        /// <param name="lockoutEndDate">The date to re-enable the account</param>
        public virtual void LockUntil(DateTime lockoutEndDate)
        {
            LockoutEndDate = new FutureOccurrence(lockoutEndDate);
        }

        /// <summary>
        /// Adds a claim to the account
        /// </summary>
        /// <param name="claim">The claim</param>
        public virtual void AddClaim(Claim claim)
        {
            if (claim == null)
            {
                throw new ArgumentNullException(nameof(claim));
            }

            AddClaim(new MongoUserClaim(claim));
        }

        /// <summary>
        /// Adds a claim to the account
        /// </summary>
        /// <param name="mongoUserClaim">The mongo user claim</param>
        public virtual void AddClaim(MongoUserClaim mongoUserClaim)
        {
            if (mongoUserClaim == null)
            {
                throw new ArgumentNullException(nameof(mongoUserClaim));
            }

            _claims.Add(mongoUserClaim);
        }

        /// <summary>
        /// Removes a claim from the account
        /// </summary>
        /// <param name="mongoUserClaim">The mongo user claim</param>
        public virtual void RemoveClaim(MongoUserClaim mongoUserClaim)
        {
            if (mongoUserClaim == null)
            {
                throw new ArgumentNullException(nameof(mongoUserClaim));
            }

            _claims.Remove(mongoUserClaim);
        }

        /// <summary>
        /// Adds a login to the account
        /// </summary>
        /// <param name="mongoUserLogin">The mongo user login</param>
        public virtual void AddLogin(MongoUserLogin mongoUserLogin)
        {
            if (mongoUserLogin == null)
            {
                throw new ArgumentNullException(nameof(mongoUserLogin));
            }

            _logins.Add(mongoUserLogin);
        }

        /// <summary>
        /// Removes a login from the account
        /// </summary>
        /// <param name="mongoUserLogin">The mongo user login</param>
        public virtual void RemoveLogin(MongoUserLogin mongoUserLogin)
        {
            if (mongoUserLogin == null)
            {
                throw new ArgumentNullException(nameof(mongoUserLogin));
            }

            _logins.Remove(mongoUserLogin);
        }

        /// <summary>
        /// Deletes the account (soft-delete)
        /// </summary>
        public void Delete()
        {
            if (DeletedOn != null)
            {
                throw new InvalidOperationException($"User '{Id}' has already been deleted.");
            }

            DeletedOn = new Occurrence();
        }

        private void EnsureClaimsIsSet()
        {
            if (_claims == null)
            {
                _claims = new List<MongoUserClaim>();
            }
        }

        private void EnsureLoginsIsSet()
        {
            if (_logins == null)
            {
                _logins = new List<MongoUserLogin>();
            }
        }
    }
}
