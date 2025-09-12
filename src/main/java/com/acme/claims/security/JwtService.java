package com.acme.claims.security;

import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor
public class JwtService {
//
//	@Autowired
//	private AppProperties props;
//
//	public String generate(String username, Object roles) {
//		var now = Instant.now();
//		return Jwts.builder().setSubject(username).addClaims(Map.of("roles", roles)).setIssuedAt(Date.from(now))
//				.setExpiration(Date.from(now.plus(props.security().jwtExpiryMinutes(), ChronoUnit.MINUTES)))
//				.signWith(Keys.hmacShaKeyFor(props.security().jwtSecret().getBytes(StandardCharsets.UTF_8)),
//						SignatureAlgorithm.HS256)
//				.compact();
//	}
//
//	public Jws<Claims> parse(String token) {
//		return Jwts.parserBuilder()
//				.setSigningKey(Keys.hmacShaKeyFor(props.security().jwtSecret().getBytes(StandardCharsets.UTF_8)))
//				.build().parseClaimsJws(token);
//	}
}
