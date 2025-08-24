# Contributing to Carambus

Thank you for your interest in contributing to Carambus! This document provides guidelines and information for contributors.

## 🤝 How to Contribute

### Reporting Issues

Before creating an issue, please:

1. **Search existing issues** to see if your problem has already been reported
2. **Check the documentation** at [https://gernotullrich.github.io/carambus-docs/](https://gernotullrich.github.io/carambus-docs/)
3. **Provide detailed information** including:
   - Rails version
   - Ruby version
   - Database type and version
   - Steps to reproduce
   - Expected vs actual behavior
   - Error messages and stack traces

### Suggesting Features

We welcome feature suggestions! Please:

1. **Describe the feature** clearly and concisely
2. **Explain the use case** and why it would be valuable
3. **Consider alternatives** and discuss trade-offs
4. **Provide examples** of how it would work

### Code Contributions

#### Prerequisites

- Ruby 3.2+
- Rails 7.2+
- PostgreSQL 12+
- Redis 6+
- Node.js 18+

#### Development Setup

1. **Fork the repository**
   ```bash
   git clone https://github.com/YOUR_USERNAME/carambus.git
   cd carambus
   ```

2. **Install dependencies**
   ```bash
   bundle install
   yarn install
   ```

3. **Setup database**
   ```bash
   bin/rails db:create
   bin/rails db:migrate
   bin/rails db:seed
   ```

4. **Start the server**
   ```bash
   bin/rails server
   ```

#### Making Changes

1. **Create a feature branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes**
   - Follow the coding standards below
   - Write tests for new functionality
   - Update documentation if needed

3. **Run tests**
   ```bash
   bin/rails test                    # All tests
   bin/rails test:system            # System tests
   bin/rails test:controllers       # Controller tests
   bin/rails test:models            # Model tests
   ```

4. **Check code quality**
   ```bash
   bundle exec standardrb --fix     # Fix code style
   bundle exec brakeman             # Security check
   bundle exec rubocop              # Linting
   ```

5. **Commit your changes**
   ```bash
   git add .
   git commit -m "Add feature: brief description"
   ```

6. **Push and create a Pull Request**
   ```bash
   git push origin feature/your-feature-name
   ```

## 📋 Coding Standards

### Ruby/Rails

- **Ruby version**: 3.2+
- **Rails version**: 7.2+
- **Code style**: Follow [Ruby Style Guide](https://github.com/rubocop/ruby-style-guide)
- **Testing**: Use RSpec for unit tests, Capybara for system tests
- **Documentation**: Document complex methods and classes

### JavaScript

- **Framework**: Stimulus.js for controllers
- **Styling**: Tailwind CSS
- **Code style**: Follow [JavaScript Standard Style](https://standardjs.com/)

### Database

- **Migrations**: Use `strong_migrations` gem for safety
- **Schema**: Document complex relationships
- **Performance**: Add indexes for frequently queried columns

### Git

- **Branch naming**: `feature/description`, `bugfix/description`, `hotfix/description`
- **Commit messages**: Use conventional commit format
- **Pull requests**: Provide clear description and link related issues

## 🧪 Testing

### Running Tests

```bash
# All tests
bin/rails test

# Specific test types
bin/rails test:system            # System tests
bin/rails test:controllers       # Controller tests
bin/rails test:models            # Model tests
bin/rails test:helpers           # Helper tests
bin/rails test:mailers           # Mailer tests

# Single test file
bin/rails test test/models/user_test.rb

# Single test method
bin/rails test test/models/user_test.rb:test_user_creation
```

### Test Coverage

- **Models**: Test validations, associations, and custom methods
- **Controllers**: Test actions, authorization, and responses
- **Views**: Test rendering and user interactions
- **Helpers**: Test utility methods
- **Mailers**: Test email content and delivery

### Test Data

- Use FactoryBot for test data
- Create realistic test scenarios
- Test edge cases and error conditions

## 🔍 Code Review Process

1. **Pull Request created** with clear description
2. **Automated checks** run (tests, linting, security)
3. **Code review** by maintainers
4. **Changes requested** if needed
5. **Approval and merge** when ready

### Review Checklist

- [ ] Tests pass
- [ ] Code follows style guidelines
- [ ] Documentation updated
- [ ] No security issues
- [ ] Performance considerations addressed
- [ ] Backward compatibility maintained

## 📚 Documentation

### Code Documentation

- **Classes and modules**: Document purpose and usage
- **Public methods**: Document parameters, return values, and examples
- **Complex logic**: Add inline comments explaining the reasoning

### User Documentation

- **User guides**: Update when features change
- **API documentation**: Document new endpoints
- **Installation guides**: Keep up to date

### Technical Documentation

- **Architecture decisions**: Document in `docs/architecture/`
- **Deployment guides**: Update for new requirements
- **Troubleshooting**: Add solutions for common issues

## 🚀 Deployment

### Development

```bash
bin/rails server                    # Start development server
bin/rails console                   # Start Rails console
bin/rails db:migrate               # Run migrations
bin/rails db:seed                  # Seed database
```

### Production

- **Environment variables**: Set in production environment
- **Database**: Ensure migrations run successfully
- **Assets**: Precompile and optimize
- **Monitoring**: Set up logging and error tracking

## 🐛 Troubleshooting

### Common Issues

1. **Database connection errors**: Check PostgreSQL service and credentials
2. **Asset compilation**: Ensure Node.js and Yarn are installed
3. **Test failures**: Check database setup and test data
4. **Performance issues**: Monitor database queries and add indexes

### Getting Help

- **Documentation**: Check [MkDocs documentation](https://gernotullrich.github.io/carambus-docs/)
- **Issues**: Search existing issues on GitHub
- **Discussions**: Use GitHub Discussions for questions
- **Community**: Reach out to maintainers

## 📝 Pull Request Template

When creating a Pull Request, please include:

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Testing
- [ ] Tests added/updated
- [ ] All tests pass
- [ ] Manual testing completed

## Checklist
- [ ] Code follows style guidelines
- [ ] Self-review completed
- [ ] Documentation updated
- [ ] No breaking changes
```

## 🙏 Recognition

Contributors will be recognized in:

- **README.md**: For significant contributions
- **CHANGELOG.md**: For all contributions
- **GitHub contributors**: Automatic recognition
- **Release notes**: For major releases

## 📄 License

By contributing to Carambus, you agree that your contributions will be licensed under the same license as the project (MIT License).

---

**Thank you for contributing to Carambus! 🎯**
